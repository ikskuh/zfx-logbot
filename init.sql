CREATE TABLE `chatlog` (
		`channel`	TEXT NOT NULL,
		`nick`	TEXT NOT NULL,
		`message`	TEXT NOT NULL,
		`timestamp`	DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
