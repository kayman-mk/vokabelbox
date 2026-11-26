<?php
declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class AddVocabularySetDescription extends AbstractMigration
{
    public function up(): void
    {
        $this->execute("ALTER TABLE vocabulary_sets
            ADD COLUMN description VARCHAR(500) NOT NULL DEFAULT '' AFTER name");
    }

    public function down(): void
    {
        $this->execute('ALTER TABLE vocabulary_sets DROP COLUMN description');
    }
}
