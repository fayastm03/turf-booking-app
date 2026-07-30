import { PrismaClient, SystemRole, TurfStatus, SlotStatus, ApplicationStatus, OfferScope, DiscountType } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seeding with normalized schema...');

  // 1. Clean existing data in reverse order of dependencies
  await prisma.paymentEvent.deleteMany();
  await prisma.blockedSlot.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.slot.deleteMany();
  await prisma.slotTemplate.deleteMany();
  await prisma.image.deleteMany();
  await prisma.staff.deleteMany();
  await prisma.role.deleteMany();
  await prisma.permission.deleteMany();
  await prisma.review.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.transaction.deleteMany();
  await prisma.wallet.deleteMany();
  await prisma.offer.deleteMany();
  await prisma.court.deleteMany();
  await prisma.turf.deleteMany();
  await prisma.ownerApplication.deleteMany();
  await prisma.document.deleteMany();
  await prisma.user.deleteMany();
  await prisma.city.deleteMany();
  await prisma.sport.deleteMany();
  await prisma.amenity.deleteMany();

  const passwordHash = await bcrypt.hash('password123', 10);

  // 2. Create Users
  const admin = await prisma.user.create({
    data: {
      email: 'admin@turf.com',
      passwordHash,
      name: 'Platform Admin',
      roles: [SystemRole.USER, SystemRole.ADMIN],
    },
  });

  const owner = await prisma.user.create({
    data: {
      email: 'owner@turf.com',
      passwordHash,
      name: 'Turf Owner',
      roles: [SystemRole.USER, SystemRole.OWNER],
    },
  });

  const customer = await prisma.user.create({
    data: {
      email: 'user@turf.com',
      passwordHash,
      name: 'Regular Customer',
      roles: [SystemRole.USER],
    },
  });

  console.log('✅ Created default users: admin@turf.com, owner@turf.com, user@turf.com (password: password123)');

  // 3. Create Wallet for user
  await prisma.wallet.create({
    data: {
      userId: customer.id,
      balance: 500.00, // Pre-load 500 credits
    },
  });
  console.log('✅ Created Wallet for customer with ₹500 balance');

  // 4. Create Owner Application
  const ownerApp = await prisma.ownerApplication.create({
    data: {
      userId: owner.id,
      businessName: 'Super Turf Arenas Inc.',
      status: ApplicationStatus.APPROVED,
    },
  });

  await prisma.document.create({
    data: {
      name: 'GST Registration Certificate',
      url: 'https://example.com/gst.pdf',
      ownerApplicationId: ownerApp.id,
    },
  });

  // 5. Seed Cities
  const mumbai = await prisma.city.create({ data: { name: 'Mumbai', state: 'Maharashtra' } });
  const bangalore = await prisma.city.create({ data: { name: 'Bangalore', state: 'Karnataka' } });
  const delhi = await prisma.city.create({ data: { name: 'Delhi', state: 'Delhi' } });

  console.log('✅ Seeded Cities: Mumbai, Bangalore, Delhi');

  // 6. Seed Sports
  const football = await prisma.sport.create({ data: { name: 'Football', iconUrl: 'sports_soccer' } });
  const cricket = await prisma.sport.create({ data: { name: 'Cricket', iconUrl: 'sports_cricket' } });
  const badminton = await prisma.sport.create({ data: { name: 'Badminton', iconUrl: 'sports_tennis' } });
  const basketball = await prisma.sport.create({ data: { name: 'Basketball', iconUrl: 'sports_basketball' } });
  const pickleball = await prisma.sport.create({ data: { name: 'Pickleball', iconUrl: 'sports_tennis' } });

  console.log('✅ Seeded Sports: Football, Cricket, Badminton, Basketball, Pickleball');

  // 7. Seed Amenities
  const shower = await prisma.amenity.create({ data: { name: 'Showers', iconUrl: 'shower' } });
  const locker = await prisma.amenity.create({ data: { name: 'Locker Rooms', iconUrl: 'meeting_room' } });
  const water = await prisma.amenity.create({ data: { name: 'Water Dispenser', iconUrl: 'local_drink' } });
  const parking = await prisma.amenity.create({ data: { name: 'Parking', iconUrl: 'local_parking' } });
  const wifi = await prisma.amenity.create({ data: { name: 'Free Wi-Fi', iconUrl: 'wifi' } });

  console.log('✅ Seeded Amenities: Showers, Lockers, Water, Parking, Wi-Fi');

  // 8. Create sample Turf
  const turf = await prisma.turf.create({
    data: {
      ownerId: owner.id,
      name: 'Camp Nou Arena',
      description: 'FIFA approved standard artificial turf with modern amenities.',
      address: '100 Football Street, Indiranagar',
      cityId: bangalore.id,
      lat: 12.9716,
      lng: 77.5946,
      basePricePerHour: 1500,
      status: TurfStatus.ACTIVE,
      openingTime: '06:00',
      closingTime: '22:00',
      slotDurationMinutes: 60,
      amenities: {
        connect: [{ id: shower.id }, { id: locker.id }, { id: water.id }, { id: parking.id }, { id: wifi.id }],
      },
    },
  });

  // Seed Turf photo
  await prisma.image.create({
    data: {
      url: 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&q=80&w=800',
      turfId: turf.id,
    },
  });

  console.log(`✅ Created Turf: ${turf.name} in Bangalore`);

  // 9. Create Courts for Turf
  const court1 = await prisma.court.create({
    data: {
      turfId: turf.id,
      name: 'Arena Pitch 1 (7v7)',
      type: 'Outdoor',
      pricePerHour: 1500,
      sports: {
        connect: [{ id: football.id }],
      },
    },
  });

  const court2 = await prisma.court.create({
    data: {
      turfId: turf.id,
      name: 'Arena Pitch 2 (Futsal)',
      type: 'Indoor',
      pricePerHour: 1200,
      sports: {
        connect: [{ id: football.id }],
      },
    },
  });

  const court3 = await prisma.court.create({
    data: {
      turfId: turf.id,
      name: 'Cricket Pitch A',
      type: 'Outdoor',
      pricePerHour: 1000,
      sports: {
        connect: [{ id: cricket.id }],
      },
    },
  });

  console.log('✅ Created Courts: Pitch 1 (7v7), Pitch 2 (Futsal), Cricket Pitch A');

  // 10. Create Slot Templates for Courts (everyday 06:00 to 22:00 hourly)
  const templates = [];
  const courts = [court1, court2, court3];

  for (const court of courts) {
    for (let day = 0; day <= 6; day++) {
      for (let hour = 6; hour <= 21; hour++) {
        const startTime = `${hour.toString().padStart(2, '0')}:00`;
        const endTime = `${(hour + 1).toString().padStart(2, '0')}:00`;
        templates.push({
          courtId: court.id,
          dayOfWeek: day,
          startTime,
          endTime,
        });
      }
    }
  }

  await prisma.slotTemplate.createMany({
    data: templates,
  });

  console.log('✅ Created Slot Templates for all courts');

  // 11. Generate Slots for next 7 days
  const today = new Date();
  const slotsToCreate = [];

  for (const court of courts) {
    for (let d = 0; d < 7; d++) {
      const targetDate = new Date();
      targetDate.setDate(today.getDate() + d);
      const dateStr = targetDate.toISOString().split('T')[0];
      const dayOfWeek = targetDate.getDay();

      for (let hour = 6; hour <= 21; hour++) {
        const startTime = `${hour.toString().padStart(2, '0')}:00`;
        const endTime = `${(hour + 1).toString().padStart(2, '0')}:00`;
        slotsToCreate.push({
          courtId: court.id,
          date: dateStr,
          startTime,
          endTime,
          price: court.pricePerHour,
          status: SlotStatus.AVAILABLE,
        });
      }
    }
  }

  await prisma.slot.createMany({
    data: slotsToCreate,
  });

  console.log(`✅ Generated ${slotsToCreate.length} active slots for all courts over the next 7 days`);

  // 12. Create Roles & Permissions for staff
  const permManageSlots = await prisma.permission.create({
    data: { name: 'manage_slots', description: 'Can configure slot templates and block slots' },
  });
  const permViewBookings = await prisma.permission.create({
    data: { name: 'view_bookings', description: 'Can view list of bookings' },
  });

  const staffRole = await prisma.role.create({
    data: {
      name: 'Receptionist',
      description: 'Front-desk operations staff',
      permissions: {
        connect: [{ id: permManageSlots.id }, { id: permViewBookings.id }],
      },
    },
  });

  // Assign staff user
  const staffUser = await prisma.user.create({
    data: {
      email: 'staff@turf.com',
      passwordHash,
      name: 'Staff Member',
      roles: [SystemRole.USER],
    },
  });

  await prisma.staff.create({
    data: {
      userId: staffUser.id,
      turfId: turf.id,
      roleId: staffRole.id,
    },
  });

  console.log('✅ Created Staff User and Dynamic Roles/Permissions');

  // 13. Create Offers
  const validFrom = new Date();
  const validTo = new Date();
  validTo.setDate(validTo.getDate() + 30);

  await prisma.offer.create({
    data: {
      scope: OfferScope.PLATFORM,
      title: 'Monsoon Kickoff 20% OFF',
      code: 'KICK20',
      discountType: DiscountType.PERCENT,
      value: 20,
      validFrom,
      validTo,
      minBookingAmount: 1000,
      isActive: true,
      cities: { connect: [{ id: bangalore.id }, { id: mumbai.id }] },
      sports: { connect: [{ id: football.id }] },
    },
  });

  await prisma.offer.create({
    data: {
      scope: OfferScope.TURF,
      title: 'Flat ₹100 Off Turf Special',
      code: 'TURF100',
      discountType: DiscountType.FIXED,
      value: 100,
      validFrom,
      validTo,
      minBookingAmount: 1000,
      isActive: true,
      turfs: { connect: [{ id: turf.id }] },
    },
  });

  console.log('✅ Seeded offer codes: KICK20, TURF100');
  console.log('🌱 Database seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
