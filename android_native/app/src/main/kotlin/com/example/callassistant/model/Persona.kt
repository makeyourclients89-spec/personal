package com.example.callassistant.model

data class ScriptStep(
    val speaker: String,
    val text: String,
    val delayMs: Long
)

data class CallerPersona(
    val id: String,
    val name: String,
    val number: String,
    val tag: String,
    val category: String,
    val urgency: String,
    val expectedIntent: String,
    val script: List<ScriptStep>
) {
    companion object {
        val presets = listOf(
            CallerPersona(
                id = "delivery",
                name = "Ramesh (Swiggy Delivery)",
                number = "+91 98765 43210",
                tag = "Food Delivery",
                category = "Delivery",
                urgency = "Low",
                expectedIntent = "Parcel guard ke paas drop karwaya gaya.",
                script = listOf(
                    ScriptStep("ai", "Namaste! Main user ka AI Assistant hoon. Kahiye kis baare me call kiya hai?", 1000),
                    ScriptStep("caller", "Bhaiya Swiggy se hoon. Flat 302 par delivery hai, security gate par khada hoon.", 2500),
                    ScriptStep("ai", "Theek hai Ramesh ji, aap parcel guard ke paas submit kar dijiye aur apna order OTP 4920 bata dijiye.", 3500),
                    ScriptStep("caller", "Theek hai sir, maine guard ko packet de diya hai.", 2500),
                    ScriptStep("ai", "Dhanyawad Ramesh ji! Have a safe delivery.", 2000)
                )
            ),
            CallerPersona(
                id = "bank",
                name = "Pooja (HDFC Bank Cards)",
                number = "+91 70001 22334",
                tag = "Credit Card Offer",
                category = "Promotional",
                urgency = "None",
                expectedIntent = "Promotional card offer declined, DND requested.",
                script = listOf(
                    ScriptStep("ai", "Namaste! Main AI Assistant hoon. Aap kis baare me baat karna chahte hain?", 1000),
                    ScriptStep("caller", "Hello sir, HDFC Bank ki taraf se Lifetime Free Credit Card offer hai.", 2500),
                    ScriptStep("ai", "Hum is offer me interested nahi hain. Kripya apna number DND list me update karein.", 3000),
                    ScriptStep("caller", "Okay sir, main system me Not Interested mark kar deti hoon.", 2000),
                    ScriptStep("ai", "Dhanyawad. Bye.", 1500)
                )
            ),
            CallerPersona(
                id = "recruiter",
                name = "Ananya (Google Recruiter)",
                number = "+91 88889 99990",
                tag = "Job Opportunity",
                category = "Recruitment",
                urgency = "High",
                expectedIntent = "Interview details emailed, 4 PM follow-up scheduled.",
                script = listOf(
                    ScriptStep("ai", "Hello! You have reached AI Call Assistant. How may I assist you?", 1000),
                    ScriptStep("caller", "Hi, calling from Google recruiting regarding the Senior Android AI role.", 2500),
                    ScriptStep("ai", "Thank you! The candidate is available. Could you please email the assessment schedule?", 3000),
                    ScriptStep("caller", "Sure, details have been emailed. We look forward to connecting at 4 PM.", 2500),
                    ScriptStep("ai", "Noted for the candidate. Thank you!", 1500)
                )
            ),
            CallerPersona(
                id = "spam",
                name = "Suspected Fraud Caller",
                number = "+91 60000 11223",
                tag = "Lottery Fraud",
                category = "Fraud / Spam",
                urgency = "Critical",
                expectedIntent = "Lottery scam detected and disconnected.",
                script = listOf(
                    ScriptStep("ai", "Namaste! Yeh call AI Assistant dwara screen ki ja rahi hai.", 1000),
                    ScriptStep("caller", "Sir aapne 25 lakh ka inaam jeeta hai! Claim karne ke liye bank details verify karein.", 2500),
                    ScriptStep("ai", "Alert: Phishing attack detected. Call disconnect ki ja rahi hai.", 2500)
                )
            )
        )
    }
}
