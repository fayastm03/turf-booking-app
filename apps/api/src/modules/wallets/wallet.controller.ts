import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { authenticate } from '../../middleware/auth';
import { prisma } from '../../db/prisma';
import { TransactionType } from '@prisma/client';
import { z } from 'zod';

export async function walletRoutes(fastify: FastifyInstance, options: FastifyPluginOptions) {
  
  // Enforce authentication on all wallet routes
  fastify.addHook('preHandler', authenticate);

  // GET /wallet - Get user's wallet balance and transaction logs
  fastify.get('/wallet', async (request, reply) => {
    try {
      let wallet = await prisma.wallet.findUnique({
        where: { userId: request.user!.id },
        include: {
          transactions: {
            orderBy: { createdAt: 'desc' },
          },
        },
      });

      if (!wallet) {
        // Automatically initialize wallet if missing
        wallet = await prisma.wallet.create({
          data: {
            userId: request.user!.id,
            balance: 0.0,
          },
          include: {
            transactions: true,
          },
        });
      }

      return reply.status(200).send(wallet);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // POST /wallet/topup - Mock Top-up adding credit immediately
  fastify.post('/wallet/topup', async (request, reply) => {
    const topupSchema = z.object({
      amount: z.number().positive(),
    });

    const parsed = topupSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    const { amount } = parsed.data;

    try {
      const updatedWallet = await prisma.$transaction(async (tx) => {
        let wallet = await tx.wallet.findUnique({
          where: { userId: request.user!.id },
        });

        if (!wallet) {
          wallet = await tx.wallet.create({
            data: {
              userId: request.user!.id,
              balance: 0.0,
            },
          });
        }

        const newBalance = wallet.balance + amount;

        // 1. Update wallet balance
        const updated = await tx.wallet.update({
          where: { id: wallet.id },
          data: { balance: newBalance },
        });

        // 2. Create CREDIT transaction record
        await tx.transaction.create({
          data: {
            userId: request.user!.id,
            walletId: wallet.id,
            type: TransactionType.WALLET_CREDIT,
            amount: amount,
            description: 'Funds Added (Mock Top-up)',
          },
        });

        // 3. Create Notification alert
        await tx.notification.create({
          data: {
            userId: request.user!.id,
            title: 'Wallet Topped-up! 💳',
            body: `₹${Math.round(amount)} has been successfully loaded into your Turf Wallet.`,
            type: 'WALLET_TOPUP',
          },
        });

        return updated;
      });

      // Fetch with updated transactions list
      const finalWallet = await prisma.wallet.findUnique({
        where: { id: updatedWallet.id },
        include: {
          transactions: {
            orderBy: { createdAt: 'desc' },
          },
        },
      });

      return reply.status(200).send(finalWallet);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // POST /wallet/pay - Process direct payment for slot reservation from wallet
  fastify.post('/wallet/pay', async (request, reply) => {
    const paySchema = z.object({
      bookingId: z.string().uuid(),
    });

    const parsed = paySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    const { bookingId } = parsed.data;

    try {
      const result = await prisma.$transaction(async (tx) => {
        // 1. Get booking
        const booking = await tx.booking.findUnique({
          where: { id: bookingId },
          include: { slot: true },
        });

        if (!booking) {
          throw new Error('Booking not found');
        }

        if (booking.status !== 'PENDING_PAYMENT') {
          throw new Error('Booking is not in pending payment state');
        }

        // 2. Lock & Get wallet balance
        let wallet = await tx.wallet.findUnique({
          where: { userId: request.user!.id },
        });

        if (!wallet) {
          wallet = await tx.wallet.create({
            data: {
              userId: request.user!.id,
              balance: 0.0,
            },
          });
        }

        if (wallet.balance < booking.amount) {
          throw new Error('Insufficient wallet balance');
        }

        // 3. Deduct balance
        const updatedWallet = await tx.wallet.update({
          where: { id: wallet.id },
          data: { balance: wallet.balance - booking.amount },
        });

        // 4. Create DEBIT transaction
        await tx.transaction.create({
          data: {
            userId: request.user!.id,
            walletId: wallet.id,
            bookingId: booking.id,
            type: TransactionType.BOOKING_CHARGE,
            amount: booking.amount,
            description: `Court Charge for Booking #${booking.id.substring(0, 8).toUpperCase()}`,
          },
        });

        // 5. Update slot and booking status
        await tx.slot.update({
          where: { id: booking.slotId },
          data: { status: 'BOOKED' },
        });

        const updatedBooking = await tx.booking.update({
          where: { id: booking.id },
          data: {
            status: 'CONFIRMED',
            razorpayPaymentId: `wallet_${Date.now()}`, // mock indicator
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

        // 6. Create Notification Alert
        await tx.notification.create({
          data: {
            userId: request.user!.id,
            title: 'Booking Confirmed! ⚽',
            body: `Your reservation for ${updatedBooking.slot.court.name} at ${updatedBooking.slot.court.turf.name} on ${updatedBooking.slot.date} (${updatedBooking.slot.startTime} - ${updatedBooking.slot.endTime}) has been paid from wallet and confirmed.`,
            type: 'BOOKING_CONFIRMED',
          },
        });

        return { wallet: updatedWallet, booking: updatedBooking };
      });

      return reply.status(200).send({
        message: 'Payment completed successfully from wallet funds',
        booking: result.booking,
      });
    } catch (err: any) {
      return reply.status(400).send({ error: 'Payment Failed', message: err.message });
    }
  });
}
