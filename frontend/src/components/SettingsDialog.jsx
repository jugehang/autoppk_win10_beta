import React, { useState } from 'react'
import useWorkbenchStore from '../stores/useWorkbenchStore'
import { X, Globe, Key, Cpu, Terminal, Save } from 'lucide-react'

const SETTINGS_TABS = [
  { id: 'general', label: 'General', icon: Globe },
  { id: 'llm', label: 'LLM', icon: Cpu },
  { id: 'api', label: 'API Keys', icon: Key },
  { id: 'paths', label: 'Paths', icon: Terminal },
]

export default function SettingsDialog() {
  const { settings, updateSettings, toggleSettings } = useWorkbenchStore()
  const [activeTab, setActiveTab] = useState('general')
  const [saved, setSaved] = useState(false)

  const handleSave = () => {
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
  }

  return (
    <div className="settings-overlay" onClick={toggleSettings}>
      <div className="settings-dialog" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3 border-b border-macos-border">
          <span className="text-[13px] font-bold text-text-primary">Settings</span>
          <button
            onClick={toggleSettings}
            className="w-6 h-6 flex items-center justify-center rounded-[5px] text-text-tertiary hover:text-text-primary hover:bg-black/[0.04] transition-colors"
          >
            <X size={14} strokeWidth={1.8} />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 flex overflow-hidden">
          {/* Tabs sidebar */}
          <div className="w-[140px] border-r border-macos-border p-2 space-y-0.5">
            {SETTINGS_TABS.map(tab => {
              const Icon = tab.icon
              return (
                <button
                  key={tab.id}
                  className={`settings-tab flex items-center gap-2 w-full text-left ${activeTab === tab.id ? 'active' : ''}`}
                  onClick={() => setActiveTab(tab.id)}
                >
                  <Icon size={13} strokeWidth={1.5} />
                  <span>{tab.label}</span>
                </button>
              )
            })}
          </div>

          {/* Content */}
          <div className="flex-1 p-5 overflow-y-auto">
            {activeTab === 'general' && (
              <div className="space-y-4">
                <h3 className="text-[12px] font-bold text-text-primary">General Settings</h3>
                <div>
                  <label className="settings-label">Default Project Directory</label>
                  <input
                    type="text"
                    className="settings-input"
                    placeholder="/path/to/projects"
                    value={settings.projectDir || ''}
                    onChange={e => updateSettings({ projectDir: e.target.value })}
                  />
                </div>
              </div>
            )}

            {activeTab === 'llm' && (
              <div className="space-y-4">
                <h3 className="text-[12px] font-bold text-text-primary">LLM Provider</h3>
                <div>
                  <label className="settings-label">Provider</label>
                  <select
                    className="settings-input"
                    value={settings.llmProvider}
                    onChange={e => updateSettings({ llmProvider: e.target.value })}
                  >
                    <option value="openai">OpenAI</option>
                    <option value="deepseek">DeepSeek</option>
                    <option value="custom">Custom</option>
                  </select>
                </div>

                {settings.llmProvider === 'openai' && (
                  <>
                    <div>
                      <label className="settings-label">Model</label>
                      <select
                        className="settings-input"
                        value={settings.openaiModel}
                        onChange={e => updateSettings({ openaiModel: e.target.value })}
                      >
                        <option value="gpt-4o">GPT-4o</option>
                        <option value="gpt-4o-mini">GPT-4o Mini</option>
                        <option value="gpt-4-turbo">GPT-4 Turbo</option>
                      </select>
                    </div>
                    <div>
                      <label className="settings-label">API Endpoint</label>
                      <input
                        type="text"
                        className="settings-input"
                        value={settings.openaiEndpoint}
                        onChange={e => updateSettings({ openaiEndpoint: e.target.value })}
                      />
                    </div>
                  </>
                )}

                {settings.llmProvider === 'deepseek' && (
                  <>
                    <div>
                      <label className="settings-label">Model</label>
                      <select
                        className="settings-input"
                        value={settings.deepseekModel}
                        onChange={e => updateSettings({ deepseekModel: e.target.value })}
                      >
                        <option value="deepseek-chat">DeepSeek Chat</option>
                        <option value="deepseek-reasoner">DeepSeek Reasoner</option>
                      </select>
                    </div>
                    <div>
                      <label className="settings-label">API Endpoint</label>
                      <input
                        type="text"
                        className="settings-input"
                        value={settings.deepseekEndpoint}
                        onChange={e => updateSettings({ deepseekEndpoint: e.target.value })}
                      />
                    </div>
                  </>
                )}
              </div>
            )}

            {activeTab === 'api' && (
              <div className="space-y-4">
                <h3 className="text-[12px] font-bold text-text-primary">API Keys</h3>
                <div>
                  <label className="settings-label">OpenAI API Key</label>
                  <input
                    type="password"
                    className="settings-input"
                    placeholder="sk-..."
                    value={settings.openaiKey}
                    onChange={e => updateSettings({ openaiKey: e.target.value })}
                  />
                </div>
                <div>
                  <label className="settings-label">DeepSeek API Key</label>
                  <input
                    type="password"
                    className="settings-input"
                    placeholder="sk-..."
                    value={settings.deepseekKey}
                    onChange={e => updateSettings({ deepseekKey: e.target.value })}
                  />
                </div>
                <p className="text-[10px] text-text-tertiary">
                  Keys are stored locally in your browser. Never shared with third parties.
                </p>
              </div>
            )}

            {activeTab === 'paths' && (
              <div className="space-y-4">
                <h3 className="text-[12px] font-bold text-text-primary">External Tool Paths</h3>
                <div>
                  <label className="settings-label">Rscript Path</label>
                  <input
                    type="text"
                    className="settings-input"
                    placeholder="Rscript"
                    value={settings.rscriptPath}
                    onChange={e => updateSettings({ rscriptPath: e.target.value })}
                  />
                </div>
                <div>
                  <label className="settings-label">Python Path</label>
                  <input
                    type="text"
                    className="settings-input"
                    placeholder="python3"
                    value={settings.pythonPath}
                    onChange={e => updateSettings({ pythonPath: e.target.value })}
                  />
                </div>
                <div>
                  <label className="settings-label">NONMEM / PsN Executable</label>
                  <input
                    type="text"
                    className="settings-input"
                    placeholder="execute"
                    value={settings.executePath || ''}
                    onChange={e => updateSettings({ executePath: e.target.value })}
                  />
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-5 py-3 border-t border-macos-border">
          <span className="text-[10px] text-text-tertiary">
            {saved ? '✓ Settings saved' : ''}
          </span>
          <button
            className="toolbar-btn-primary"
            onClick={handleSave}
          >
            <Save size={12} strokeWidth={2} />
            <span>Save</span>
          </button>
        </div>
      </div>
    </div>
  )
}
