import { index, integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

export const feedbackPosts = sqliteTable(
  "feedback_posts",
  {
    id: text("id").primaryKey(),
    nickname: text("nickname").notNull(),
    passwordSalt: text("password_salt").notNull(),
    passwordHash: text("password_hash").notNull(),
    category: text("category").notNull(),
    title: text("title").notNull(),
    body: text("body").notNull(),
    status: text("status").notNull().default("new"),
    likes: integer("likes").notNull().default(0),
    createdAt: integer("created_at").notNull(),
    updatedAt: integer("updated_at").notNull(),
  },
  (table) => [
    index("feedback_posts_created_at_idx").on(table.createdAt),
    index("feedback_posts_status_idx").on(table.status),
  ],
);

export const feedbackReplies = sqliteTable(
  "feedback_replies",
  {
    id: text("id").primaryKey(),
    postId: text("post_id")
      .notNull()
      .references(() => feedbackPosts.id, { onDelete: "cascade" }),
    author: text("author").notNull().default("Memorize Me 운영자"),
    body: text("body").notNull(),
    createdAt: integer("created_at").notNull(),
  },
  (table) => [index("feedback_replies_post_id_idx").on(table.postId)],
);

export const feedbackReactions = sqliteTable(
  "feedback_reactions",
  {
    id: text("id").primaryKey(),
    postId: text("post_id")
      .notNull()
      .references(() => feedbackPosts.id, { onDelete: "cascade" }),
    voterHash: text("voter_hash").notNull(),
    createdAt: integer("created_at").notNull(),
  },
  (table) => [
    uniqueIndex("feedback_reactions_post_voter_idx").on(table.postId, table.voterHash),
  ],
);

export const feedbackRateLimits = sqliteTable("feedback_rate_limits", {
  fingerprint: text("fingerprint").primaryKey(),
  windowStart: integer("window_start").notNull(),
  count: integer("count").notNull().default(0),
});
