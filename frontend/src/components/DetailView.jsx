import React, { useMemo, useState } from 'react'
import useWorkbenchStore from '../stores/useWorkbenchStore'
import { FileText, Table2 } from 'lucide-react'

export default function DetailView() {
  const { selectedAsset, fileContent, parameters, assets } = useWorkbenchStore()
  const [activeTab, setActiveTab] = useState('preview')

  if (!selectedAsset) {
    return (
      <div className="flex-1 flex items-center justify-center bg-macos-panel rounded-macos
                      border border-macos-border shadow-macos mx-1 mt-1">
        <div className="text-center select-none">
          <div className="text-4xl mb-3 text-text-tertiary/40">📂</div>
          <p className="text-[13px] text-text-secondary font-medium">Select a file from the sidebar</p>
          <p className="text-[11px] text-text-tertiary mt-1">
            Choose a model, output, or diagnostic to view details
          </p>
        </div>
      </div>
    )
  }

  const isModel = selectedAsset.category === 'models'
  const isImage = selectedAsset.name.match(/\.(png|jpg|jpeg|gif|webp|svg)$/i)
  const isPdf = selectedAsset.name.endsWith('.pdf')
  const lineCount = fileContent ? fileContent.split('\n').length : 0

  const tabs = [
    { id: 'preview', label: 'Preview', icon: FileText },
    ...(isModel && parameters.length > 0 ? [{ id: 'params', label: 'Parameters', icon: Table2 }] : []),
  ]

  return (
    <div className="flex-1 flex flex-col detail-view mx-1 mt-1 min-h-[380px]">
      {/* Header */}
      <div className="detail-header">
        <div className="flex items-center gap-2 min-w-0">
          <span className="text-[15px]">{selectedAsset.icon}</span>
          <span className="text-[13px] font-semibold text-text-primary truncate">
            {selectedAsset.name}
          </span>
          <span className="text-[10px] text-text-tertiary font-mono bg-black/[0.03] px-1.5 py-0.5 rounded">
            {lineCount} lines
          </span>
        </div>

        <div className="flex items-center gap-0.5 bg-black/[0.03] rounded-[7px] p-0.5">
          {tabs.map(tab => {
            const Icon = tab.icon
            return (
              <button
                key={tab.id}
                className={`detail-tab flex items-center gap-1.5 ${activeTab === tab.id ? 'active' : ''}`}
                onClick={() => setActiveTab(tab.id)}
              >
                <Icon size={12} strokeWidth={1.8} />
                <span>{tab.label}</span>
              </button>
            )
          })}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-hidden">
        {activeTab === 'preview' && (
          isImage ? (
            <div className="flex items-center justify-center h-full bg-[#fafafa]">
              <img
                src={`/api/project/file-content?dir=${encodeURIComponent(useWorkbenchStore.getState().projectDir || '')}&path=${encodeURIComponent(selectedAsset.path || selectedAsset.name)}`}
                alt={selectedAsset.name}
                className="max-w-full max-h-full object-contain"
              />
            </div>
          ) : (
            <div className="code-preview h-full">
              {fileContent ? (
                <pre className="whitespace-pre-wrap break-all">
                  {fileContent.split('\n').map((line, i) => (
                    <div key={i} className="flex">
                      <span className="line-number">{i + 1}</span>
                      <span className="flex-1">{line || ' '}</span>
                    </div>
                  ))}
                </pre>
              ) : (
                <div className="flex items-center justify-center h-full text-text-tertiary text-[12px]">
                  Loading...
                </div>
              )}
            </div>
          )
        )}

        {activeTab === 'params' && (
          <div className="overflow-auto h-full">
            <table className="params-table">
              <thead>
                <tr>
                  <th>Parameter</th>
                  <th>Estimate</th>
                  <th>RSE%</th>
                  <th>95% CI</th>
                  <th>Shrinkage%</th>
                </tr>
              </thead>
              <tbody>
                {parameters.map((p, i) => (
                  <tr key={i}>
                    <td className="font-mono font-medium">{p.parameter || p.name || p.Parameter}</td>
                    <td className="font-mono">{p.estimate ?? p.Estimate ?? '-'}</td>
                    <td className="font-mono">{p.rse ?? p.RSE ?? p['RSE%'] ?? '-'}</td>
                    <td className="font-mono text-[11px]">{p.ci95 ?? p['95%CI'] ?? '-'}</td>
                    <td className="font-mono">{p.shrinkage ?? p.Shrinkage ?? p['Shrinkage%'] ?? '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Status bar */}
      <div className="status-bar">
        <span className="text-[10px] truncate">{selectedAsset.path || selectedAsset.name}</span>
      </div>
    </div>
  )
}
