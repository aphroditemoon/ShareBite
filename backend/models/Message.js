// PostgreSQL version: data access is implemented with SQL queries in routes and db/*.
// This file is kept only to document the former model boundary.
module.exports = {
  Message: { table: 'messages', primaryKey: 'id' },
  Conversation: { table: 'conversations', primaryKey: 'id' },
};
