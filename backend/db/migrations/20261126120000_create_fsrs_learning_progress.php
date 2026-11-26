<?php
declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class CreateFsrsLearningProgress extends AbstractMigration
{
    public function up(): void
    {
        $this->execute("CREATE TABLE learning_progress (
            user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            vocabulary_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            learning_method VARCHAR(20) NOT NULL,
            direction VARCHAR(32) NOT NULL,
            algorithm_version VARCHAR(20) NOT NULL,
            state VARCHAR(20) NOT NULL DEFAULT 'new',
            stability DOUBLE NULL,
            difficulty DOUBLE NULL,
            repetitions INT UNSIGNED NOT NULL DEFAULT 0,
            lapses INT UNSIGNED NOT NULL DEFAULT 0,
            last_review_at DATETIME NULL,
            due_at DATETIME NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (user_id, vocabulary_id, learning_method, direction),
            INDEX idx_learning_progress_due (user_id, learning_method, direction, due_at),
            CONSTRAINT fk_learning_progress_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            CONSTRAINT fk_learning_progress_vocabulary FOREIGN KEY (vocabulary_id) REFERENCES vocabularies(id) ON DELETE CASCADE,
            CONSTRAINT chk_learning_progress_method CHECK (learning_method IN ('fsrs')),
            CONSTRAINT chk_learning_progress_direction CHECK (direction IN ('foreign_to_local', 'local_to_foreign'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci");

        $this->execute("CREATE TABLE learning_review_events (
            id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            vocabulary_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            learning_method VARCHAR(20) NOT NULL,
            direction VARCHAR(32) NOT NULL,
            algorithm_version VARCHAR(20) NOT NULL,
            rating TINYINT UNSIGNED NOT NULL,
            reviewed_at DATETIME NOT NULL,
            stability_before DOUBLE NULL,
            stability_after DOUBLE NOT NULL,
            difficulty_before DOUBLE NULL,
            difficulty_after DOUBLE NOT NULL,
            due_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            INDEX idx_learning_review_history (user_id, vocabulary_id, learning_method, direction, reviewed_at),
            CONSTRAINT fk_learning_review_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            CONSTRAINT fk_learning_review_vocabulary FOREIGN KEY (vocabulary_id) REFERENCES vocabularies(id) ON DELETE CASCADE,
            CONSTRAINT chk_learning_review_method CHECK (learning_method IN ('fsrs')),
            CONSTRAINT chk_learning_review_direction CHECK (direction IN ('foreign_to_local', 'local_to_foreign')),
            CONSTRAINT chk_learning_review_rating CHECK (rating BETWEEN 1 AND 4)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci");
    }

    public function down(): void
    {
        $this->execute('DROP TABLE IF EXISTS learning_review_events');
        $this->execute('DROP TABLE IF EXISTS learning_progress');
    }
}
