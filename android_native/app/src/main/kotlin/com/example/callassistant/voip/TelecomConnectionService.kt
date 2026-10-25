package com.example.callassistant.voip

import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle

class TelecomConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val connection = VoipConnection()
        connection.setInitializing()
        connection.setActive()
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val connection = VoipConnection()
        connection.setInitializing()
        connection.setActive()
        return connection
    }
}

class VoipConnection : Connection() {
    override fun onAnswer() {
        super.onAnswer()
        setActive()
        TwilioVoiceManager.answerByUser()
    }

    override fun onReject() {
        super.onReject()
        setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
        destroy()
        TwilioVoiceManager.declineCall()
    }

    override fun onDisconnect() {
        super.onDisconnect()
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
        TwilioVoiceManager.endCall()
    }
}
