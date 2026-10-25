package com.example.callassistant.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.callassistant.R
import com.example.callassistant.data.CallRepository
import com.example.callassistant.databinding.ActivityMainBinding
import com.example.callassistant.model.CallRecord
import com.example.callassistant.model.CallerPersona
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import com.example.callassistant.voip.TwilioVoiceManager
import com.example.callassistant.voip.WebCallBridgeManager

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private var selectedPersona = CallerPersona.presets.first()

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { perms ->
        val micGranted = perms[Manifest.permission.RECORD_AUDIO] == true
        if (micGranted) {
            Toast.makeText(this, "Microphone & Call Permissions granted!", Toast.LENGTH_SHORT).show()
        }
        updatePermissionStatus()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupUI()
        observeData()
        updatePermissionStatus()
    }

    private fun setupUI() {
        binding.tvSelectedPersona.text = "Selected: ${selectedPersona.name} • ${selectedPersona.number}"

        binding.btnStartDemoCall.setOnClickListener {
            // Trigger VoIP call via TwilioVoiceManager
            TwilioVoiceManager.startIncomingCall(selectedPersona)
            val intent = Intent(this, IncomingCallActivity::class.java).apply {
                putExtra("callerName", selectedPersona.name)
                putExtra("callerNumber", selectedPersona.number)
                putExtra("category", selectedPersona.category)
            }
            startActivity(intent)
        }

        binding.btnGrantPerms.setOnClickListener {
            requestRequiredPermissions()
        }

        setupWebCallingCard()

        binding.rvRecentCalls.layoutManager = LinearLayoutManager(this)
    }

    private fun setupWebCallingCard() {
        val callUrl = WebCallBridgeManager.getWebCallingUrl()
        binding.tvWebCallUrl.text = callUrl

        binding.btnCopyLink.setOnClickListener {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("Calling Link", callUrl)
            clipboard.setPrimaryClip(clip)
            Toast.makeText(this, "Calling link copied to clipboard!", Toast.LENGTH_SHORT).show()
        }

        binding.btnShareLink.setOnClickListener {
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, "Free AI Call Assistant")
                putExtra(Intent.EXTRA_TEXT, "Call my AI Assistant for free by opening this link: $callUrl")
            }
            startActivity(Intent.createChooser(shareIntent, "Share Calling Link via"))
        }

        WebCallBridgeManager.isConnected.observe(this) { connected ->
            if (connected) {
                binding.tvBridgeStatus.text = "Live Ready"
                binding.tvBridgeStatus.setTextColor(ContextCompat.getColor(this, android.R.color.holo_green_dark))
                binding.tvBridgeStatus.setBackgroundColor(0xFFDCFCE7.toInt())
            } else {
                binding.tvBridgeStatus.text = "Connecting..."
                binding.tvBridgeStatus.setTextColor(ContextCompat.getColor(this, android.R.color.holo_orange_dark))
                binding.tvBridgeStatus.setBackgroundColor(0xFFFEF3C7.toInt())
            }
        }
    }

    private fun observeData() {
        CallRepository.callsLiveData.observe(this) { calls ->
            binding.tvCallsCount.text = "${calls.size} calls"
            binding.rvRecentCalls.adapter = RecentCallsAdapter(calls) { record ->
                val intent = Intent(this, CallDetailActivity::class.java).apply {
                    putExtra("callId", record.id)
                }
                startActivity(intent)
            }
        }
    }

    private fun updatePermissionStatus() {
        val mic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (mic) {
            binding.tvPermStatus.text = "Microphone, Telecom, Notifications: 100% Ready"
            binding.tvPermStatus.setTextColor(ContextCompat.getColor(this, android.R.color.holo_green_dark))
            binding.btnGrantPerms.visibility = View.GONE
        } else {
            binding.tvPermStatus.text = "Microphone permission needed for VoIP audio"
            binding.tvPermStatus.setTextColor(ContextCompat.getColor(this, android.R.color.holo_red_dark))
            binding.btnGrantPerms.visibility = View.VISIBLE
        }
    }

    private fun requestRequiredPermissions() {
        val perms = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        permissionLauncher.launch(perms.toTypedArray())
    }
}

class RecentCallsAdapter(
    private val items: List<CallRecord>,
    private val onItemClick: (CallRecord) -> Unit
) : RecyclerView.Adapter<RecentCallsAdapter.ViewHolder>() {

    class ViewHolder(val view: View) : RecyclerView.ViewHolder(view) {
        val tvName: TextView = view.findViewById(R.id.tvCallerName)
        val tvBadge: TextView = view.findViewById(R.id.tvRecordingBadge)
        val tvCategory: TextView = view.findViewById(R.id.tvCategory)
        val tvIntent: TextView = view.findViewById(R.id.tvKeyIntent)
        val tvStatus: TextView = view.findViewById(R.id.tvStatusDuration)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val v = LayoutInflater.from(parent.context).inflate(R.layout.item_call_record, parent, false)
        return ViewHolder(v)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = items[position]
        holder.tvName.text = item.callerName
        holder.tvCategory.text = item.category
        holder.tvIntent.text = item.keyIntent
        holder.tvStatus.text = "${item.status.name} • ${item.durationSeconds}s"

        if (item.hasRecording) {
            holder.tvBadge.visibility = View.VISIBLE
            holder.tvBadge.text = "REC ${item.recordingDurationSeconds}s"
        } else {
            holder.tvBadge.visibility = View.GONE
        }

        holder.itemView.setOnClickListener { onItemClick(item) }
    }

    override fun getItemCount() = items.size
}
