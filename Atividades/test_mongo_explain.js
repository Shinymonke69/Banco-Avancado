const ticketDb = db.getSiblingDB("ticket_core");

const resQ4Before = ticketDb.orders.find({ status: "pending" }).sort({ expires_at: 1 }).explain("executionStats");
print("--- Q4 BEFORE INDEX ---");
print("Docs examined: " + resQ4Before.executionStats.totalDocsExamined);
print("Keys examined: " + resQ4Before.executionStats.totalKeysExamined);
print("Time millis: " + resQ4Before.executionStats.executionTimeMillis);
print("Stage: " + resQ4Before.executionStats.executionStages.stage);

const resQ1Before = ticketDb.orders.explain("executionStats").aggregate([
  { $match: { status: "confirmed", created_at: { $gte: ISODate("2026-10-01T00:00:00Z"), $lte: ISODate("2026-10-31T23:59:59Z") } } },
  { $unwind: "$items" },
  { $group: { _id: "$items.event_name", total: { $sum: "$items.total" } } }
]);
print("--- Q1 BEFORE INDEX ---");
print(JSON.stringify(resQ1Before.stages ? resQ1Before.stages[0] : resQ1Before.executionStats));

