<?php
declare(strict_types=1);

/** FSRS-4.5 scheduler using the published default parameter set and 90% retention. */
function fsrs_review(?float $stability, ?float $difficulty, ?string $lastReviewAt, int $rating, DateTimeImmutable $now): array
{
    if ($rating < 1 || $rating > 4) {
        throw new InvalidArgumentException('FSRS rating must be between 1 and 4.');
    }

    $w = [0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755];
    if ($stability === null || $difficulty === null || $lastReviewAt === null) {
        $nextStability = $w[$rating - 1];
        $nextDifficulty = fsrs_clamp($w[4] - exp($w[5] * ($rating - 1)) + 1, 1.0, 10.0);
    } else {
        $lastReview = new DateTimeImmutable($lastReviewAt, new DateTimeZone('UTC'));
        $elapsedDays = max(0.0, ($now->getTimestamp() - $lastReview->getTimestamp()) / 86400);
        $retrievability = (1 + (19 / 81) * $elapsedDays / max($stability, 0.001)) ** -0.5;
        $initialEasyDifficulty = $w[4] - exp($w[5] * (4 - 1)) + 1;
        $nextDifficulty = fsrs_clamp(
            $w[7] * $initialEasyDifficulty + (1 - $w[7]) * ($difficulty - $w[6] * ($rating - 3)),
            1.0,
            10.0
        );
        if ($rating === 1) {
            $nextStability = $w[11] * ($difficulty ** (-$w[12])) * ((($stability + 1) ** $w[13]) - 1) * exp($w[14] * (1 - $retrievability));
            $nextStability = min($nextStability, $stability);
        } else {
            $ratingMultiplier = $rating === 2 ? $w[15] : ($rating === 4 ? $w[16] : 1.0);
            $nextStability = $stability * (1 + exp($w[8]) * (11 - $difficulty) * ($stability ** (-$w[9])) * (exp($w[10] * (1 - $retrievability)) - 1) * $ratingMultiplier);
        }
    }

    $intervalDays = min(36500, max(1, (int)round($nextStability)));
    $dueAt = $now->modify('+' . $intervalDays . ' days');
    return [
        'stability' => $nextStability,
        'difficulty' => $nextDifficulty,
        'dueAt' => $dueAt,
        'intervalDays' => $intervalDays,
    ];
}

function fsrs_clamp(float $value, float $minimum, float $maximum): float
{
    return min($maximum, max($minimum, $value));
}
