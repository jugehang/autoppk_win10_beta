import React from 'react'
import useWorkbenchStore from './stores/useWorkbenchStore'
import Toolbar from './components/Toolbar'
import Sidebar from './components/Sidebar'
import DetailView from './components/DetailView'
import TerminalView from './components/TerminalView'
import AIAssistant from './components/AIAssistant'
import SettingsDialog from './components/SettingsDialog'
import ContextMenu from './components/ContextMenu'

export default function App() {
  const { showSettings, showAI } = useWorkbenchStore()

  return (
    <div className="h-screen flex flex-col overflow-hidden select-none">
      {/* Toolbar */}
      <Toolbar />

      {/* Main content area — three-panel */}
      <div className="flex-1 flex overflow-hidden">
        {/* Sidebar */}
        <Sidebar />

        {/* Center: Detail + Terminal (VSplitView) */}
        <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
          <DetailView />
          <TerminalView />
        </div>
      </div>

      {/* AI Assistant overlay */}
      {showAI && <AIAssistant />}

      {/* Settings Dialog */}
      {showSettings && <SettingsDialog />}

      {/* Context Menu */}
      <ContextMenu />
    </div>
  )
}
