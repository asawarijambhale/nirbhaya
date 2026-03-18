package com.example.nirbhaya

/**
 * Pure Kotlin keyword matching — case-insensitive substring + all-words fuzzy match.
 * Mirrors the Dart KeywordMatcher logic so behaviour is identical on both sides.
 */
object KeywordDetector {

    /**
     * Returns true if [spoken] contains [codeword] (case-insensitive),
     * or if every word in [codeword] appears somewhere in [spoken].
     */
    fun matches(spoken: String, codeword: String): Boolean {
        if (codeword.isBlank()) return false

        val spokenNorm  = spoken.trim().lowercase()
        val codeNorm    = codeword.trim().lowercase()

        // Fast path: exact substring
        if (spokenNorm.contains(codeNorm)) return true

        // Fuzzy: every word of the codeword must appear in spoken words
        val codeWords   = codeNorm.split(Regex("\\s+"))
        val spokenWords = spokenNorm.split(Regex("\\s+"))
        return codeWords.all { it in spokenWords }
    }
}
