import React, { useState, useRef, useEffect, useCallback } from 'react'
import useWorkbenchStore from '../stores/useWorkbenchStore'
import { X, Send, MessageSquare, Sparkles } from 'lucide-react'
import ReactMarkdown from 'react-markdown'
import * as api from '../services/api'

export default function AIAssistant() {
  const {
    showAI, toggleAI, aiMessages, aiLoading,
    addAIMessage, setAILoading, clearAIChat,
    settings, selectedAsset, fileContent,
  } = useWorkbenchStore()

  const [input, setInput] = useState('')
  const bodyRef = useRef(null)
  const inputRef = useRef(null)

  // Auto-scroll to bottom
  useEffect(() => {
    if (bodyRef.current) {
      bodyRef.current.scrollTop = bodyRef.current.scrollHeight
    }
  }, [aiMessages, aiLoading])

  // Focus input when opened
  useEffect(() => {
    if (showAI && inputRef.current) {
      inputRef.current.focus()
    }
  }, [showAI])

  const handleSend = useCallback(async () => {
    const text = input.trim()
    if (!text || aiLoading) return

    addAIMessage('user', text)
    setInput('')
    setAILoading(true)

    // Build context
    const contextItems = []
    if (selectedAsset && fileContent) {
      contextItems.push({
        type: 'file',
        path: selectedAsset.name,
        content: fileContent.slice(0, 8000),
      })
    }

    // Build system prompt
    const systemPrompt = `You are DuDu, a Pharmacometrics AI assistant specialized in PopPK/PD modeling with NONMEM, PsN, and R. You help users interpret model outputs, diagnose issues, and suggest next steps. Current model context may be provided. Be concise and professional.`

    const messages = [
      { role: 'system', content: systemPrompt },
      ...contextItems.map(c => ({
        role: 'system',
        content: `File: ${c.path}\n\`\`\`\n${c.content}\n\`\`\``,
      })),
      ...aiMessages.map(m => ({ role: m.role, content: m.content })),
    ]

    try {
      const providerKey = settings.llmProvider === 'deepseek' ? settings.deepseekKey : settings.openaiKey
      const providerModel = settings.llmProvider === 'deepseek' ? settings.deepseekModel : settings.openaiModel
      const providerEndpoint = settings.llmProvider === 'deepseek' ? settings.deepseekEndpoint : settings.openaiEndpoint

      const response = await api.sendChatMessage(messages, {
        provider: settings.llmProvider,
        apiKey: providerKey,
        model: providerModel,
        endpoint: providerEndpoint,
      })

      addAIMessage('assistant', response.content || response.message || 'No response.')
    } catch (e) {
      addAIMessage('assistant', `Error: ${e.message}. Please check your LLM settings.`)
    } finally {
      setAILoading(false)
    }
  }, [input, aiLoading, aiMessages, settings, selectedAsset, fileContent, addAIMessage, setAILoading])

  const handleKeyDown = useCallback((e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }, [handleSend])

  return (
    <div className="ai-overlay">
      <div className="ai-card">
        {/* Header */}
        <div className="ai-card-header">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-full flex items-center justify-center"
                 style={{
                   background: 'linear-gradient(135deg, #2667cc 0%, #59a6ff 100%)',
                 }}>
              <Sparkles size={14} strokeWidth={2} className="text-white" />
            </div>
            <div>
              <span className="text-[13px] font-bold text-text-primary">DuDu</span>
              <span className="text-[10px] text-text-tertiary ml-1.5">PMx Assistant</span>
            </div>
          </div>

          <div className="flex items-center gap-1">
            <button
              onClick={clearAIChat}
              className="text-[10px] text-text-tertiary hover:text-text-primary px-2 py-1 rounded-[5px] hover:bg-black/[0.04] transition-colors"
            >
              Clear
            </button>
            <button
              onClick={toggleAI}
              className="w-6 h-6 flex items-center justify-center rounded-[5px] text-text-tertiary hover:text-text-primary hover:bg-black/[0.04] transition-colors"
            >
              <X size={14} strokeWidth={1.8} />
            </button>
          </div>
        </div>

        {/* Messages */}
        <div ref={bodyRef} className="ai-card-body">
          {aiMessages.length === 0 && (
            <div className="text-center py-8 select-none">
              <div className="text-3xl mb-3">🤖</div>
              <p className="text-[13px] text-text-secondary font-medium">How can I help with your PK model?</p>
              <p className="text-[11px] text-text-tertiary mt-1">
                Ask me about GOF diagnostics, parameter interpretation, or model optimization
              </p>
            </div>
          )}

          {aiMessages.map((msg, i) => (
            <div key={i} className={`ai-bubble ${msg.role}`}>
              {msg.role === 'assistant' ? (
                <ReactMarkdown
                  className="prose prose-sm max-w-none text-[13px]"
                  components={{
                    p: ({ children }) => <p className="mb-1 last:mb-0">{children}</p>,
                    code: ({ children, ...props }) => (
                      <code className="bg-black/[0.06] px-1 py-0.5 rounded text-[11px]" {...props}>
                        {children}
                      </code>
                    ),
                    pre: ({ children }) => (
                      <pre className="bg-black/[0.04] p-2 rounded-[6px] text-[11px] overflow-x-auto my-1">
                        {children}
                      </pre>
                    ),
                  }}
                >
                  {msg.content}
                </ReactMarkdown>
              ) : (
                <span>{msg.content}</span>
              )}
            </div>
          ))}

          {aiLoading && (
            <div className="ai-thinking">
              <span className="dot" />
              <span className="dot" />
              <span className="dot" />
            </div>
          )}
        </div>

        {/* Input */}
        <div className="ai-card-footer">
          <div className="flex items-end gap-2">
            <textarea
              ref={inputRef}
              value={input}
              onChange={e => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Ask DuDu about your model..."
              rows={2}
              className="ai-input"
              disabled={aiLoading}
            />
            <button
              onClick={handleSend}
              disabled={!input.trim() || aiLoading}
              className="ai-send-btn"
              title="Send"
            >
              <Send size={14} strokeWidth={2} />
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
