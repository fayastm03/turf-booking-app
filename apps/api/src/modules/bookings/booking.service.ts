import { prisma } from '../../db/prisma';
import { redis } from '../../db/redis';
import { BookingStatus, SlotStatus, Slot } from '@prisma/client';
import Razorpay from 'razorpay';
import { config } from '../../config';

const razorpay = new Razorpay({
  key_id: config.RAZORPAY_KEY_ID,
  key_secret: config.RAZORPAY_KEY_SECRET,
});

export interface HoldResult {
  bookingId: string;
  expiresAt: string;
  amount: number;
}

export async function holdSlot(userId: string, slotId: string, offerCode?: string): Promise<HoldResult> {
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes hold

  const booking = await prisma.$transaction(async (tx) => {
    // 1. SELECT FOR UPDATE on slot row to serialize concurrent requests
    const slots: Slot[] = await tx.$queryRaw`
      SELECT * FROM slots 
      WHERE id = ${slotId} 
      FOR UPDATE
    `;

    const slot = slots[0];
    if (!slot) {
      throw new Error('Slot not found');
    }

    if (slot.status !== SlotStatus.AVAILABLE) {
      throw new Error('Slot is no longer available');
    }

    // 2. Double-check concurrency hold in Redis to avoid race conditions
    const redisLockKey = `hold:${slotId}`;
    const acquiredLock = await redis.set(redisLockKey, userId, 'NX', 'EX', 300); // 5 minutes (300s)
    if (!acquiredLock) {
      throw new Error('Slot is currently being booked by another user');
    }

    // 3. Apply discount rules if offerCode is provided
    let amount = slot.price;
    let appliedOfferId: string | undefined;

    if (offerCode) {
      const offer = await tx.offer.findUnique({
        where: { code: offerCode.toUpperCase() },
        include: {
          turfs: { select: { id: true } },
          cities: { select: { id: true } },
          sports: { select: { id: true } },
        },
      });

      if (offer && offer.isActive && new Date() >= offer.validFrom && new Date() <= offer.validTo) {
        let isEligible = true;

        if (offer.scope === 'TURF') {
          const court = await tx.court.findUnique({
            where: { id: slot.courtId },
            select: { turfId: true },
          });
          const turfId = court?.turfId;

          if (!offer.turfs.some((t) => t.id === turfId)) {
            isEligible = false;
          }
        }

        if (offer.minBookingAmount && slot.price < offer.minBookingAmount) {
          isEligible = false;
        }

        if (isEligible) {
          appliedOfferId = offer.id;
          if (offer.discountType === 'PERCENT') {
            const discount = (slot.price * offer.value) / 100;
            amount = Math.max(0, slot.price - discount);
          } else if (offer.discountType === 'FIXED') {
            amount = Math.max(0, slot.price - offer.value);
          }
        }
      }
    }

    // 4. Update slot status in DB
    await tx.slot.update({
      where: { id: slotId },
      data: { status: SlotStatus.HELD },
    });

    // 5. Create temporary booking with raw status PENDING_PAYMENT
    const newBooking = await tx.booking.create({
      data: {
        userId,
        courtId: slot.courtId,
        slotId: slot.id,
        status: BookingStatus.PENDING_PAYMENT,
        amount,
        offerId: appliedOfferId || null,
        razorpayOrderId: `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      },
    });

    return newBooking;
  });

  return {
    bookingId: booking.id,
    expiresAt: expiresAt.toISOString(),
    amount: booking.amount,
  };
}

export async function createRazorpayOrder(bookingId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { slot: true },
  });

  if (!booking) {
    throw new Error('Booking not found');
  }

  if (booking.status !== BookingStatus.PENDING_PAYMENT) {
    throw new Error(`Cannot create order for booking with status: ${booking.status}`);
  }

  // Ensure hold hasn't expired
  const lockExists = await redis.get(`hold:${booking.slotId}`);
  if (!lockExists) {
    await prisma.$transaction([
      prisma.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.EXPIRED },
      }),
      prisma.slot.update({
        where: { id: booking.slotId },
        data: { status: SlotStatus.AVAILABLE },
      }),
    ]);
    throw new Error('Booking hold has expired');
  }

  const order = await razorpay.orders.create({
    amount: Math.round(booking.amount * 100), // in paise
    currency: 'INR',
    receipt: bookingId,
  });

  await prisma.booking.update({
    where: { id: bookingId },
    data: { razorpayOrderId: order.id },
  });

  return {
    orderId: order.id,
    amount: booking.amount,
    key: config.RAZORPAY_KEY_ID,
  };
}

export async function confirmBooking(razorpayOrderId: string, razorpayPaymentId: string) {
  return prisma.$transaction(async (tx) => {
    const booking = await tx.booking.findUnique({
      where: { razorpayOrderId },
    });

    if (!booking) {
      throw new Error(`Booking with order ID ${razorpayOrderId} not found`);
    }

    if (booking.status === BookingStatus.CONFIRMED) {
      return booking;
    }

    // Confirm booking and set slot as BOOKED
    const updatedBooking = await tx.booking.update({
      where: { id: booking.id },
      data: {
        status: BookingStatus.CONFIRMED,
        razorpayPaymentId,
      },
      include: {
        slot: {
          include: {
            court: {
              include: {
                turf: true,
              },
            },
          },
        },
      },
    });

    await tx.slot.update({
      where: { id: booking.slotId },
      data: { status: SlotStatus.BOOKED },
    });

    // Create Notification
    await tx.notification.create({
      data: {
        userId: booking.userId,
        title: 'Booking Confirmed! ⚽',
        body: `Your reservation for ${updatedBooking.slot.court.name} at ${updatedBooking.slot.court.turf.name} on ${updatedBooking.slot.date} (${updatedBooking.slot.startTime} - ${updatedBooking.slot.endTime}) is confirmed. See you on the pitch!`,
        type: 'BOOKING_CONFIRMED',
      },
    });

    // Remove lock in Redis
    await redis.del(`hold:${booking.slotId}`);

    return updatedBooking;
  });
}

export async function cancelBooking(userId: string, bookingId: string, isAdmin = false) {
  return prisma.$transaction(async (tx) => {
    const booking = await tx.booking.findUnique({
      where: { id: bookingId },
      include: { slot: true },
    });

    if (!booking) {
      throw new Error('Booking not found');
    }

    if (!isAdmin && booking.userId !== userId) {
      throw new Error('Unauthorized to cancel this booking');
    }

    if (booking.status !== BookingStatus.CONFIRMED) {
      throw new Error(`Cannot cancel booking with status: ${booking.status}`);
    }

    // Check cancellation window (at least 2 hours before slot date and start time)
    const slotDateTime = new Date(`${booking.slot.date}T${booking.slot.startTime}:00Z`);
    const hoursDifference = (slotDateTime.getTime() - Date.now()) / (1000 * 60 * 60);

    if (!isAdmin && hoursDifference < 2) {
      throw new Error('Cancellations are only allowed up to 2 hours before the booking time');
    }

    let refundId: string | undefined;
    if (booking.razorpayPaymentId) {
      try {
        const refund = await razorpay.payments.refund(booking.razorpayPaymentId, {
          speed: 'normal',
        });
        refundId = refund.id;
      } catch (err: any) {
        console.error('Razorpay refund failed:', err);
        throw new Error(`Refund failed: ${err.message}`);
      }
    }

    const updated = await tx.booking.update({
      where: { id: bookingId },
      data: {
        status: refundId ? BookingStatus.REFUNDED : BookingStatus.CANCELLED,
        razorpayRefundId: refundId || null,
        cancelledAt: new Date(),
      },
      include: {
        slot: {
          include: {
            court: {
              include: {
                turf: true,
              },
            },
          },
        },
      },
    });

    await tx.slot.update({
      where: { id: booking.slotId },
      data: { status: SlotStatus.AVAILABLE },
    });

    // Create Notification
    await tx.notification.create({
      data: {
        userId: booking.userId,
        title: 'Booking Cancelled ⚠️',
        body: `Your reservation for ${updated.slot.court.name} at ${updated.slot.court.turf.name} on ${updated.slot.date} has been cancelled. A refund of ₹${Math.round(updated.amount)} has been initiated.`,
        type: 'BOOKING_CANCELLED',
      },
    });

    return updated;
  });
}

export async function cleanupExpiredBookings() {
  const threshold = new Date(Date.now() - 5 * 60 * 1000); // 5 minutes ago

  const expiredBookings = await prisma.booking.findMany({
    where: {
      status: BookingStatus.PENDING_PAYMENT,
      createdAt: { lt: threshold },
    },
  });

  let count = 0;
  for (const booking of expiredBookings) {
    try {
      await prisma.$transaction([
        prisma.booking.update({
          where: { id: booking.id },
          data: { status: BookingStatus.EXPIRED },
        }),
        prisma.slot.update({
          where: { id: booking.slotId },
          data: { status: SlotStatus.AVAILABLE },
        }),
      ]);
      await redis.del(`hold:${booking.slotId}`);
      count++;
    } catch (err) {
      console.error(`Failed to expire booking ${booking.id}:`, err);
    }
  }

  return count;
}
