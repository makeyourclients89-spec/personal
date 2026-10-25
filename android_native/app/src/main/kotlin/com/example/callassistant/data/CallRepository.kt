package com.example.callassistant.data

import android.content.Context
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import com.example.callassistant.model.CallRecord
import com.example.callassistant.model.CallStatus
import com.example.callassistant.model.TranscriptItem

object CallRepository {
    private val _callsLiveData = MutableLiveData<List<CallRecord>>(emptyList())
    val callsLiveData: LiveData<List<CallRecord>> = _callsLiveData

    private val inMemoryRecords = mutableListOf<CallRecord>()

    fun init(context: Context) {
        if (inMemoryRecords.isEmpty()) {
            loadInitialSeedData()
        }
    }

    private fun loadInitialSeedData() {
        val now = System.currentTimeMillis()
        inMemoryRecords.addAll(
            listOf(
                CallRecord(
                    id = "seed_01",
                    callerName = "Ramesh (Swiggy Delivery)",
                    callerNumber = "+91 98765 43210",
                    timestamp = now - (25 * 60 * 1000),
                    durationSeconds = 42,
                    category = "Food Delivery",
                    status = CallStatus.AI_ANSWERED,
                    keyIntent = "Parcel security guard ke paas drop karwaya gaya (OTP 4920).",
                    aiSummary = "Swiggy delivery partner ne gate se call kiya. AI assistant ne instruction diya ki package guard ko submit karein. Order successfully handed over.",
                    urgency = "Low",
                    hasRecording = true,
                    recordingDurationSeconds = 42,
                    recordingUrl = "https://api.twilio.com/recordings/demo_01.wav",
                    transcript = listOf(
                        TranscriptItem("ai", "Namaste! Main user ka AI Call Assistant hoon. Kahiye kis baare me call kiya hai?", "00:02"),
                        TranscriptItem("caller", "Bhaiya Swiggy se hoon. Flat 302 par delivery hai, gate par guard jaane nahi de raha.", "00:09"),
                        TranscriptItem("ai", "Theek hai Ramesh ji, aap parcel guard ke paas submit kar dijiye aur apna order OTP 4920 bata dijiye.", "00:20"),
                        TranscriptItem("caller", "Theek hai sir, maine guard ko parcel de diya hai.", "00:33"),
                        TranscriptItem("ai", "Dhanyawad Ramesh ji! Have a safe delivery.", "00:41")
                    )
                ),
                CallRecord(
                    id = "seed_02",
                    callerName = "Pooja (HDFC Bank Cards)",
                    callerNumber = "+91 70001 22334",
                    timestamp = now - (2 * 3600 * 1000),
                    durationSeconds = 28,
                    category = "Promotional",
                    status = CallStatus.AI_ANSWERED,
                    keyIntent = "Unsolicited credit card offer declined, DND requested.",
                    aiSummary = "Telemarketing executive ne credit card pitch kiya. AI assistant ne politely refuse karke phone number DND me add karne ka request initiate kiya.",
                    urgency = "None",
                    hasRecording = true,
                    recordingDurationSeconds = 28,
                    recordingUrl = "https://api.twilio.com/recordings/demo_02.wav",
                    transcript = listOf(
                        TranscriptItem("ai", "Namaste! Main AI Assistant hoon. Aap kis baare me baat karna chahte hain?", "00:02"),
                        TranscriptItem("caller", "Hello sir, HDFC Bank ki taraf se Lifetime Free Credit Card offer hai.", "00:10"),
                        TranscriptItem("ai", "Hum is offer me interested nahi hain. Kripya hamara number DND list me daal dijiye.", "00:18"),
                        TranscriptItem("caller", "Okay sir, main system me record update kar deti hoon.", "00:24"),
                        TranscriptItem("ai", "Dhanyawad. Call disconnect ki ja rahi hai.", "00:27")
                    )
                )
            )
        )
        _callsLiveData.postValue(inMemoryRecords.toList())
    }

    fun addCallRecord(record: CallRecord) {
        inMemoryRecords.add(0, record)
        _callsLiveData.postValue(inMemoryRecords.toList())
    }

    fun getCallById(id: String): CallRecord? {
        return inMemoryRecords.find { it.id == id }
    }

    fun getAllCalls(): List<CallRecord> {
        return inMemoryRecords.toList()
    }
}
