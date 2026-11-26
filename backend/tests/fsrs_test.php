<?php
declare(strict_types=1);

require __DIR__ . '/../src/fsrs.php';

function check(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

function checkNear(float $actual, float $expected, string $message): void
{
    check(abs($actual - $expected) < 0.000001, $message . " (expected {$expected}, got {$actual})");
}

$start = new DateTimeImmutable('2026-01-01 12:00:00', new DateTimeZone('UTC'));
$firstReviewExpectations = [
    1 => ['stability' => 0.4872, 'difficulty' => 5.1618, 'intervalDays' => 1],
    2 => ['stability' => 1.4003, 'difficulty' => 2.741254641197556, 'intervalDays' => 1],
    3 => ['stability' => 3.7145, 'difficulty' => 1.0, 'intervalDays' => 4],
    4 => ['stability' => 13.8206, 'difficulty' => 1.0, 'intervalDays' => 14],
];

foreach ($firstReviewExpectations as $rating => $expected) {
    $schedule = fsrs_review(null, null, null, $rating, $start);
    checkNear($schedule['stability'], $expected['stability'], "Rating {$rating} produced the wrong initial stability.");
    checkNear($schedule['difficulty'], $expected['difficulty'], "Rating {$rating} produced the wrong initial difficulty.");
    check($schedule['intervalDays'] === $expected['intervalDays'], "Rating {$rating} produced the wrong first interval.");
    check($schedule['dueAt']->getTimestamp() === $start->modify('+' . $expected['intervalDays'] . ' days')->getTimestamp(), "Rating {$rating} produced the wrong due date.");
}

$previousStability = 5.0;
$previousDifficulty = 5.0;
$lastReviewAt = '2026-01-01 12:00:00';
$reviewAt = new DateTimeImmutable('2026-01-05 12:00:00', new DateTimeZone('UTC'));
$elapsedDays = 4.0;
$retrievability = (1 + (19 / 81) * $elapsedDays / $previousStability) ** -0.5;
$weights = [0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755];
$expectedGoodStability = $previousStability * (1 + exp($weights[8]) * (11 - $previousDifficulty) * ($previousStability ** (-$weights[9])) * (exp($weights[10] * (1 - $retrievability)) - 1));
$good = fsrs_review($previousStability, $previousDifficulty, $lastReviewAt, 3, $reviewAt);
checkNear($good['stability'], $expectedGoodStability, 'A successful review did not apply the FSRS-4.5 stability update.');
checkNear($good['difficulty'], 4.876, 'A Good review did not apply difficulty mean reversion toward the initial Easy difficulty.');
check($good['stability'] > $previousStability, 'A successful overdue review should increase stability.');

$expectedAgainStability = $weights[11]
    * ($previousDifficulty ** (-$weights[12]))
    * ((($previousStability + 1) ** $weights[13]) - 1)
    * exp($weights[14] * (1 - $retrievability));
$again = fsrs_review($previousStability, $previousDifficulty, $lastReviewAt, 1, $reviewAt);
checkNear($again['stability'], min($expectedAgainStability, $previousStability), 'An Again review did not apply the FSRS-4.5 lapse update.');
check($again['stability'] <= $previousStability, 'An Again review must not increase stability.');
check($again['difficulty'] > $previousDifficulty && $again['difficulty'] <= 10, 'An Again review should increase bounded difficulty.');

$sameDay = fsrs_review(2.0, 5.0, '2026-01-05 09:00:00', 3, $reviewAt);
check($sameDay['intervalDays'] >= 1, 'A same-day review must still schedule a valid minimum interval.');

$invalidRatingRejected = false;
try {
    fsrs_review(null, null, null, 0, $start);
} catch (InvalidArgumentException) {
    $invalidRatingRejected = true;
}
check($invalidRatingRejected, 'The scheduler must reject ratings outside the FSRS rating range.');

fwrite(STDOUT, "FSRS-4.5 scheduler tests passed.\n");
