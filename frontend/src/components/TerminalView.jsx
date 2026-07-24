import React, { useRef, useEffect } from 'react'
import useWorkbenchStore from '../stores/useWorkbenchStore'
import { Terminal } from 'lucide-react'

export default function TerminalView() {
  const { terminalOutput, isRunning } = useWorkbenchStore()
  const bodyRef = useRef(null)

  useEffect(() => {
    if (bodyRef.current) {
      bodyRef.current.scrollTop = bodyRef.current.scrollHeight
    }
  }, [terminalOutput])

  return (
    <div className="terminal mx-1 my-1" style={{ minHeight: 150, maxHeight: 300 }}>
      {/* Header bar */}
      <div className="terminal-header">
        <div className="flex items-center gap-1.5">
          <div className="terminal-dot red" />
          <div className="terminal-dot yellow" />
          <div className="terminal-dot green" />
        </div>
        <div className="flex items-center gap-1.5 ml-2">
          <Terminal size={11} strokeWidth={1.5} className="text-white/50" />
          <span className="text-[10px] text-white/50 font-medium">Terminal</span>
        </div>
        {isRunning && (
          <span className="text-[10px] text-run-cyan animate-pulse-soft ml-auto">Running...</span>
        )}
      </div>

      {/* Output body */}
      <div ref={bodyRef} className="terminal-body">
        {terminalOutput.length === 0 ? (
          <div className="flex items-center justify-center h-full">
            <div className="text-center select-none">
              <p className="text-[12px] text-white/25 font-mono">
                Ready. Run a model or command to see output.
              </p>
            </div>
          </div>
        ) : (
          terminalOutput.map((line, i) => (
            <div key={i} className={`terminal-line ${line.type || 'stdout'}`}>
              {line.type === 'info' && <span className="terminal-prompt">$</span>}
              {line.text}
            </div>
          ))
        )}
      </div>
    </div>
  )
}
