const ticketDb = db.getSiblingDB("ticket_core");

ticketDb.orders.createIndex({ status: 1, expires_at: 1 });
ticketDb.orders.createIndex({ status: 1, created_at: 1 });

const resQ4After = ticketDb.orders.find({ status: "pending" }).sort({ expires_at: 1 }).explain("executionStats");
print("--- Q4 AFTER INDEX ---");
print("Docs examined: " + resQ4After.executionStats.totalDocsExamined);
print("Keys examined: " + resQ4After.executionStats.totalKeysExamined);
print("Time millis: " + resQ4After.executionStats.executionTimeMillis);
print("Stage: " + resQ4After.executionStats.executionStages.stage);

const resQ1After = ticketDb.orders.explain("executionStats").aggregate([
  { $match: { status: "confirmed", created_at: { $gte: ISODate("2026-10-01T00:00:00Z"), $lte: ISODate("2026-10-31T23:59:59Z") } } },
  { $unwind: "$items" },
  { $group: { _id: "$items.event_name", total: { $sum: "$items.total" } } }
]);
print("--- Q1 AFTER INDEX ---");
const cursorStats = resQ1After.stages ? resQ1After.stages[0].$cursor.executionStats : resQ1After.executionStats;
print("Docs examined: " + cursorStats.totalDocsExamined);
print("Keys examined: " + cursorStats.totalKeysExamined);
print("Time millis: " + cursorStats.executionTimeMillis);
print("Stage: " + cursorStats.executionStages.stage);

