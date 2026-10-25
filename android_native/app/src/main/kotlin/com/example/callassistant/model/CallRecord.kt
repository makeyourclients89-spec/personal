package com.example.callassistant.model

data class TranscriptItem(
    val speaker: String, // "caller" | "ai" | "user"
    val text: String,
    val timestamp: String
)

data class CallRecord(
    val id: String,
    val callerName: String,
    val callerNumber: String,
    val timestamp: Long,
    val durationSeconds: Int,
    val category: String,
    val status: CallStatus,
    val keyIntent: String,
    val aiSummary: String,
    val urgency: String,
    val transcript: List<TranscriptItem>,
    val hasRecording: Boolean = true,
    val recordingDurationSeconds: Int = durationSeconds,
    val recordingUrl: String? = null
)
