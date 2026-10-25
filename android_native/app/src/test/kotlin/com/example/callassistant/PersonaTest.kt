package com.example.callassistant

import com.example.callassistant.model.CallerPersona
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PersonaTest {

    @Test
    fun testAllPresetPersonasExistAndHaveValidScripts() {
        val presets = CallerPersona.presets
        assertEquals(4, presets.size)

        for (persona in presets) {
            assertTrue(persona.name.isNotEmpty())
            assertTrue(persona.number.isNotEmpty())
            assertTrue(persona.expectedIntent.isNotEmpty())
            assertTrue(persona.script.isNotEmpty())

            for (step in persona.script) {
                assertTrue(step.text.isNotEmpty())
                assertTrue(listOf("ai", "caller").contains(step.speaker))
                assertTrue(step.delayMs >= 1000)
            }
        }
    }
}
