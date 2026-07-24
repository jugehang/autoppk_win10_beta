import React, { useRef, useEffect, useCallback } from 'react'
import useWorkbenchStore from '../stores/useWorkbenchStore'
import { Folder, Sparkles, Play, RefreshCw, Wrench, Code2 } from 'lucide-react'

export default function Toolbar() {
  const {
    projectDir, projectName, isRunning,
    toggleAI, toggleSettings,
    runCommand, commandText, setProject, loadAssets,
  } = useWorkbenchStore()

  const dirInputRef = useRef(null)

  const handleOpenProject = useCallback(() => {
    const dir = prompt('Enter project directory path:', projectDir || '/path/to/project')
    if (dir) {
      setProject(dir)
      setTimeout(() => loadAssets(), 100)
    }
  }, [projectDir, setProject, loadAssets])

  const handleRunModel = useCallback(() => {
    if (!commandText || isRunning) return
    runCommand(commandText)
  }, [commandText, isRunning, runCommand])

  return (
    <div className="toolbar">
      {/* Logo & Brand */}
      <div className="flex items-center gap-2 min-w-[190px]">
        <div className="w-7 h-7 rounded-[7px] flex items-center justify-center shrink-0"
             style={{
               background: 'linear-gradient(135deg, #2667cc 0%, #59a6ff 100%)',
               boxShadow: '0 2px 6px rgba(38,103,204,0.15)',
             }}>
          <span className="text-white text-[14px] font-bold" style={{ fontFamily: '"SF Pro Rounded", system-ui' }}>A</span>
        </div>
        <div className="flex flex-col leading-tight">
          <span className="text-[14px] font-bold text-text-primary">AutoPMX</span>
          <span className="text-[10px] font-medium text-text-tertiary">DuDu PMx Workbench</span>
        </div>
      </div>

      {/* Divider */}
      <div className="toolbar-divider" />

      {/* File Actions */}
      <button className="toolbar-btn" onClick={handleOpenProject} title="Open Project">
        <Folder size={13} strokeWidth={1.8} />
        <span>Open</span>
      </button>

      <button className="toolbar-btn-demo" title="Open Demo Project with guided AI PPK examples">
        <Sparkles size={13} strokeWidth={1.8} />
        <span>Demo</span>
      </button>

      {/* Divider */}
      <div className="toolbar-divider" />

      {/* Primary Action */}
      <button
        className="toolbar-btn-primary"
        onClick={handleRunModel}
        disabled={!commandText || isRunning}
        title="Run NONMEM model"
      >
        {isRunning ? (
          <RefreshCw size={12} strokeWidth={2.5} className="animate-spin" />
        ) : (
          <Play size={12} strokeWidth={2.5} fill="currentColor" className="ml-0.5" />
        )}
        <span>{isRunning ? 'Running...' : 'Run Model'}</span>
      </button>

      {/* Spacer */}
      <div className="flex-1" />

      {/* Claude Code Button */}
      <button className="toolbar-btn-claude" title="Open Claude Code panel">
        <Code2 size={13} strokeWidth={1.8} />
        <span>Claude Code</span>
      </button>

      {/* Settings */}
      <button className="toolbar-btn" onClick={toggleSettings} title="Settings">
        <Wrench size={13} strokeWidth={1.8} />
      </button>

      {/* Project Location Badge */}
      {projectDir && (
        <div className="location-badge">
          <Folder size={11} strokeWidth={1.5} className="text-primary-start/70" />
          <div className="flex flex-col leading-none overflow-hidden">
            <span className="text-[11px] font-semibold text-text-primary truncate">{projectName}</span>
            <span className="text-[9px] text-text-tertiary truncate">{projectDir}</span>
          </div>
        </div>
      )}
    </div>
  )
}
