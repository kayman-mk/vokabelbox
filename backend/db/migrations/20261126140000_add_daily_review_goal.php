<?php
declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddDailyReviewGoal extends AbstractMigration
{
    public function up(): void
    {
        $this->execute('ALTER TABLE users ADD COLUMN daily_review_goal SMALLINT UNSIGNED NOT NULL DEFAULT 10');
    }

    public function down(): void
    {
        $this->execute('ALTER TABLE users DROP COLUMN daily_review_goal');
    }
}
