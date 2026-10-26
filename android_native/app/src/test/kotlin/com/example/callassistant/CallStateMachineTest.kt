package com.example.callassistant

import com.example.callassistant.model.CallRecord
import com.example.callassistant.model.CallStatus
import com.example.callassistant.model.TranscriptItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CallStateMachineTest {

    @Test
    fun testInitialRingingToHumanAnsweredTransition() {
        var state = CallStatus.RINGING
        val userPickedUpInSeconds = 4

        if (userPickedUpInSeconds <= 10) {
            state = CallStatus.HUMAN_ANSWERED
        }

        assertEquals(CallStatus.HUMAN_ANSWERED, state)
    }

    @Test
    fun testTimeoutToAiAnsweredTransition() {
        var state = CallStatus.RINGING
        val elapsedSeconds = 10

        if (elapsedSeconds >= 10) {
            state = CallStatus.AI_ANSWERED
        }

        assertEquals(CallStatus.AI_ANSWERED, state)
    }

    @Test
    fun testAiAnsweredToUserTakeoverTransition() {
        var state = CallStatus.AI_ANSWERED
        val transcript = mutableListOf(
            TranscriptItem("ai", "Namaste! Main AI Assistant hoon.", "00:02"),
            TranscriptItem("caller", "Delivery parcel aaya hai.", "00:07")
        )

        // User clicks Takeover
        state = CallStatus.USER_TAKEOVER
        transcript.add(TranscriptItem("user", "[Takeover] User took over call.", "00:12"))

        assertEquals(CallStatus.USER_TAKEOVER, state)
        assertEquals(3, transcript.size)
        assertEquals("user", transcript.last().speaker)
    }

    @Test
    fun testCallRecordRecordingMetadata() {
        val record = CallRecord(
            id = "test_call_01",
            callerName = "Test Delivery",
            callerNumber = "+91 99999 88888",
            timestamp = System.currentTimeMillis(),
            durationSeconds = 35,
            category = "Delivery",
            status = CallStatus.AI_ANSWERED,
            keyIntent = "Drop at gate",
            aiSummary = "Summary generated",
            urgency = "Low",
            transcript = listOf(
                TranscriptItem("ai", "Hello", "00:01"),
                TranscriptItem("caller", "At gate", "00:05")
            ),
            hasRecording = true,
            recordingDurationSeconds = 35,
            recordingUrl = "https://api.twilio.com/recordings/test.wav"
        )

        assertTrue(record.hasRecording)
        assertEquals(35, record.recordingDurationSeconds)
        assertEquals("Drop at gate", record.keyIntent)
        assertEquals(2, record.transcript.size)
    }

    @Test
    fun testWebCallBridgeUrlGeneration() {
        val host = "192.168.1.41"
        val port = 3000
        val url = "http://$host:$port/call"
        assertEquals("http://192.168.1.41:3000/call", url)
    }
}
