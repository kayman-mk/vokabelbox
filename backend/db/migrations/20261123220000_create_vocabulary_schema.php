<?php
declare(strict_types=1);

use Phinx\Migration\AbstractMigration;

final class CreateVocabularySchema extends AbstractMigration
{
    public function up(): void
    {
        if (!$this->hasTable('users')) {
            $this->createUuidSchema();
            return;
        }

        $types = [
            $this->columnType('users'),
            $this->columnType('vocabulary_sets'),
            $this->columnType('vocabularies'),
        ];
        $areUuid = array_map(static fn(string $type): bool => str_contains(strtolower($type), 'char(36)'), $types);
        if ($areUuid === [true, true, true]) {
            return;
        }
        if ($areUuid !== [false, false, false]) {
            throw new RuntimeException('Database tables have mixed ID types. Restore a backup before retrying the UUID migration.');
        }

        $this->upgradeLegacyIntegerIds();
    }

    public function down(): void
    {
        if (!$this->hasTable('users')) {
            return;
        }

        $this->convertUuidsToIntegerIds();
    }

    private function createUuidSchema(): void
    {
        $this->execute("CREATE TABLE users (
            id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            username VARCHAR(80) NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci");

        $this->execute("CREATE TABLE vocabulary_sets (
            id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            name VARCHAR(120) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_vocabulary_sets_owner_created (owner_user_id, created_at),
            CONSTRAINT fk_vocabulary_sets_owner FOREIGN KEY (owner_user_id)
                REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci");

        $this->execute("CREATE TABLE vocabularies (
            id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            vocabulary_set_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            prompt VARCHAR(255) NOT NULL,
            answer VARCHAR(500) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_vocabularies_set_created (vocabulary_set_id, created_at),
            CONSTRAINT fk_vocabularies_set FOREIGN KEY (vocabulary_set_id)
                REFERENCES vocabulary_sets(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci");
    }

    private function upgradeLegacyIntegerIds(): void
    {
        foreach (['users', 'vocabulary_sets', 'vocabularies'] as $table) {
            if (!$this->hasTable($table)) {
                throw new RuntimeException("Legacy database is missing the {$table} table.");
            }
        }

        $this->execute("ALTER TABLE users ADD COLUMN uuid_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL");
        $this->execute("ALTER TABLE vocabulary_sets
            ADD COLUMN uuid_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
            ADD COLUMN owner_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL");
        $this->execute("ALTER TABLE vocabularies
            ADD COLUMN uuid_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
            ADD COLUMN vocabulary_set_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL");

        $this->execute('UPDATE users SET uuid_id = UUID() WHERE uuid_id IS NULL');
        $this->execute('UPDATE vocabulary_sets SET uuid_id = UUID() WHERE uuid_id IS NULL');
        $this->execute('UPDATE vocabularies SET uuid_id = UUID() WHERE uuid_id IS NULL');
        $this->execute('UPDATE vocabulary_sets s JOIN users u ON u.id = s.owner_user_id SET s.owner_uuid = u.uuid_id WHERE s.owner_uuid IS NULL');
        $this->execute('UPDATE vocabularies v JOIN vocabulary_sets s ON s.id = v.vocabulary_set_id SET v.vocabulary_set_uuid = s.uuid_id WHERE v.vocabulary_set_uuid IS NULL');

        foreach ([
            'SELECT COUNT(*) AS total FROM users WHERE uuid_id IS NULL',
            'SELECT COUNT(*) AS total FROM vocabulary_sets WHERE uuid_id IS NULL OR owner_uuid IS NULL',
            'SELECT COUNT(*) AS total FROM vocabularies WHERE uuid_id IS NULL OR vocabulary_set_uuid IS NULL',
        ] as $query) {
            if ((int)$this->fetchRow($query)['total'] !== 0) {
                throw new RuntimeException('Could not map every legacy row to a UUID. No legacy columns were removed.');
            }
        }

        $this->execute('ALTER TABLE vocabularies DROP FOREIGN KEY fk_vocabularies_set, DROP INDEX idx_vocabularies_set_created');
        $this->execute('ALTER TABLE vocabulary_sets DROP FOREIGN KEY fk_vocabulary_sets_owner, DROP INDEX idx_vocabulary_sets_owner_created');
        $this->execute("ALTER TABLE users
            DROP PRIMARY KEY,
            DROP COLUMN id,
            CHANGE COLUMN uuid_id id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            ADD PRIMARY KEY (id)");
        $this->execute("ALTER TABLE vocabulary_sets
            DROP PRIMARY KEY,
            DROP COLUMN id,
            DROP COLUMN owner_user_id,
            CHANGE COLUMN uuid_id id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            CHANGE COLUMN owner_uuid owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            ADD PRIMARY KEY (id),
            ADD INDEX idx_vocabulary_sets_owner_created (owner_user_id, created_at),
            ADD CONSTRAINT fk_vocabulary_sets_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE");
        $this->execute("ALTER TABLE vocabularies
            DROP PRIMARY KEY,
            DROP COLUMN id,
            DROP COLUMN vocabulary_set_id,
            CHANGE COLUMN uuid_id id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            CHANGE COLUMN vocabulary_set_uuid vocabulary_set_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            ADD PRIMARY KEY (id),
            ADD INDEX idx_vocabularies_set_created (vocabulary_set_id, created_at),
            ADD CONSTRAINT fk_vocabularies_set FOREIGN KEY (vocabulary_set_id) REFERENCES vocabulary_sets(id) ON DELETE CASCADE");
    }

    private function convertUuidsToIntegerIds(): void
    {
        $types = [
            $this->columnType('users'),
            $this->columnType('vocabulary_sets'),
            $this->columnType('vocabularies'),
        ];
        $areUuid = array_map(static fn(string $type): bool => str_contains(strtolower($type), 'char(36)'), $types);
        if ($areUuid !== [true, true, true]) {
            throw new RuntimeException('Cannot roll back a database with mixed ID types.');
        }

        $this->execute('ALTER TABLE users ADD COLUMN legacy_id BIGINT UNSIGNED NULL');
        $this->execute('ALTER TABLE vocabulary_sets
            ADD COLUMN legacy_id BIGINT UNSIGNED NULL,
            ADD COLUMN legacy_owner_user_id BIGINT UNSIGNED NULL');
        $this->execute('ALTER TABLE vocabularies
            ADD COLUMN legacy_id BIGINT UNSIGNED NULL,
            ADD COLUMN legacy_vocabulary_set_id BIGINT UNSIGNED NULL');
        $this->numberRows('users');
        $this->numberRows('vocabulary_sets');
        $this->numberRows('vocabularies');
        $this->execute('UPDATE vocabulary_sets s JOIN users u ON u.id = s.owner_user_id SET s.legacy_owner_user_id = u.legacy_id');
        $this->execute('UPDATE vocabularies v JOIN vocabulary_sets s ON s.id = v.vocabulary_set_id SET v.legacy_vocabulary_set_id = s.legacy_id');
        if ((int)$this->fetchRow('SELECT COUNT(*) AS total FROM vocabulary_sets WHERE legacy_owner_user_id IS NULL')['total'] !== 0
            || (int)$this->fetchRow('SELECT COUNT(*) AS total FROM vocabularies WHERE legacy_vocabulary_set_id IS NULL')['total'] !== 0) {
            throw new RuntimeException('Could not map every UUID relationship back to an integer ID.');
        }

        $this->execute('ALTER TABLE vocabularies DROP FOREIGN KEY fk_vocabularies_set, DROP INDEX idx_vocabularies_set_created');
        $this->execute('ALTER TABLE vocabulary_sets DROP FOREIGN KEY fk_vocabulary_sets_owner, DROP INDEX idx_vocabulary_sets_owner_created');
        $this->execute("ALTER TABLE users
            DROP PRIMARY KEY,
            DROP COLUMN id,
            CHANGE COLUMN legacy_id id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            ADD PRIMARY KEY (id)");
        $this->execute("ALTER TABLE vocabulary_sets
            DROP PRIMARY KEY,
            DROP COLUMN id,
            DROP COLUMN owner_user_id,
            CHANGE COLUMN legacy_id id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            CHANGE COLUMN legacy_owner_user_id owner_user_id BIGINT UNSIGNED NOT NULL,
            ADD PRIMARY KEY (id),
            ADD INDEX idx_vocabulary_sets_owner_created (owner_user_id, created_at),
            ADD CONSTRAINT fk_vocabulary_sets_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE");
        $this->execute("ALTER TABLE vocabularies
            DROP PRIMARY KEY,
            DROP COLUMN id,
            DROP COLUMN vocabulary_set_id,
            CHANGE COLUMN legacy_id id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            CHANGE COLUMN legacy_vocabulary_set_id vocabulary_set_id BIGINT UNSIGNED NOT NULL,
            ADD PRIMARY KEY (id),
            ADD INDEX idx_vocabularies_set_created (vocabulary_set_id, created_at),
            ADD CONSTRAINT fk_vocabularies_set FOREIGN KEY (vocabulary_set_id) REFERENCES vocabulary_sets(id) ON DELETE CASCADE");
    }

    private function numberRows(string $table): void
    {
        $this->execute('SET @legacy_id := 0');
        $this->execute("UPDATE `{$table}` SET legacy_id = (@legacy_id := @legacy_id + 1) ORDER BY id");
    }

    private function columnType(string $table): string
    {
        $column = $this->fetchRow("SHOW COLUMNS FROM `{$table}` WHERE Field = 'id'");
        if ($column === false) {
            throw new RuntimeException("The {$table}.id column does not exist.");
        }
        return (string)$column['Type'];
    }
}
