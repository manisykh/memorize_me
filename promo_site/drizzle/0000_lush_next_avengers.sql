CREATE TABLE `feedback_posts` (
	`id` text PRIMARY KEY NOT NULL,
	`nickname` text NOT NULL,
	`password_salt` text NOT NULL,
	`password_hash` text NOT NULL,
	`category` text NOT NULL,
	`title` text NOT NULL,
	`body` text NOT NULL,
	`status` text DEFAULT 'new' NOT NULL,
	`likes` integer DEFAULT 0 NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `feedback_posts_created_at_idx` ON `feedback_posts` (`created_at`);--> statement-breakpoint
CREATE INDEX `feedback_posts_status_idx` ON `feedback_posts` (`status`);--> statement-breakpoint
CREATE TABLE `feedback_rate_limits` (
	`fingerprint` text PRIMARY KEY NOT NULL,
	`window_start` integer NOT NULL,
	`count` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE `feedback_reactions` (
	`id` text PRIMARY KEY NOT NULL,
	`post_id` text NOT NULL,
	`voter_hash` text NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`post_id`) REFERENCES `feedback_posts`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `feedback_reactions_post_voter_idx` ON `feedback_reactions` (`post_id`,`voter_hash`);--> statement-breakpoint
CREATE TABLE `feedback_replies` (
	`id` text PRIMARY KEY NOT NULL,
	`post_id` text NOT NULL,
	`author` text DEFAULT 'Memorize Me 운영자' NOT NULL,
	`body` text NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`post_id`) REFERENCES `feedback_posts`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `feedback_replies_post_id_idx` ON `feedback_replies` (`post_id`);