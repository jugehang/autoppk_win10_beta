import React, { useCallback, useState } from 'react'
import useWorkbenchStore, { assetCategories } from '../stores/useWorkbenchStore'
import { ChevronRight, ChevronDown } from 'lucide-react'

export default function Sidebar() {
  const {
    assets, selectedAsset, selectedCategory,
    selectAsset, setSelectedCategory,
    showContextMenu,
  } = useWorkbenchStore()

  const [collapsed, setCollapsed] = useState({})
  const [search, setSearch] = useState('')

  const toggleCategory = (catId) => {
    setCollapsed(prev => ({ ...prev, [catId]: !prev[catId] }))
    setSelectedCategory(catId)
  }

  const handleRowClick = useCallback((asset) => {
    selectAsset(asset)
  }, [selectAsset])

  const handleContextMenu = useCallback((e, asset, category) => {
    e.preventDefault()
    const items = buildContextMenuItems(asset, category)
    showContextMenu(e.clientX, e.clientY, items)
  }, [showContextMenu])

  const filteredAssets = {}
  const searchLower = search.toLowerCase()
  for (const cat of assetCategories) {
    const catAssets = assets[cat.id] || []
    filteredAssets[cat.id] = searchLower
      ? catAssets.filter(a => a.name.toLowerCase().includes(searchLower))
      : catAssets
  }

  // Count visible
  const totalVisible = Object.values(filteredAssets).reduce((s, a) => s + a.length, 0)

  return (
    <div className="sidebar">
      {/* Header */}
      <div className="sidebar-section-header">
        <div className="flex items-center gap-1.5 mb-1">
          <span className="text-[12px] text-text-secondary">📂</span>
          <span className="text-[12px] font-bold text-text-primary">Project Explorer</span>
        </div>
        <p className="text-[10px] text-text-tertiary pl-[18px]">Models, diagnostics, reports</p>

        {/* Search */}
        <div className="mt-2 relative">
          <input
            type="text"
            placeholder="Filter files..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full bg-black/[0.04] border border-black/[0.08] rounded-[6px]
                       px-2 py-1 text-[11px] outline-none
                       focus:border-primary-start/30 focus:bg-white
                       placeholder:text-text-placeholder transition-colors"
          />
          {search && (
            <span className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] text-text-tertiary">
              {totalVisible} items
            </span>
          )}
        </div>
      </div>

      {/* Category list */}
      <div className="flex-1 overflow-y-auto py-1">
        {assetCategories.map(cat => {
          const catAssets = filteredAssets[cat.id] || []
          if (catAssets.length === 0 && search) return null
          const isOpen = !collapsed[cat.id]
          const isActive = selectedCategory === cat.id

          return (
            <div key={cat.id}>
              {/* Category header — DisclosureGroup style */}
              <div
                className={`sidebar-category ${isActive ? 'active' : ''}`}
                onClick={() => toggleCategory(cat.id)}
              >
                {isOpen ? (
                  <ChevronDown size={10} strokeWidth={2} />
                ) : (
                  <ChevronRight size={10} strokeWidth={2} />
                )}
                <span className="text-[12px] w-[18px] text-center">{cat.symbol}</span>
                <span className="text-[12px] font-semibold flex-1">{cat.title}</span>
                <span className="sidebar-badge">{catAssets.length}</span>
              </div>

              {/* Asset rows */}
              {isOpen && catAssets.map(asset => {
                const isSelected = selectedAsset?.name === asset.name
                const relPath = asset.path || asset.name
                const isRoot = !(relPath.includes('/') || relPath.includes('\\'))
                return (
                  <div
                    key={asset.name}
                    className={`sidebar-row ${isSelected ? 'selected' : ''}`}
                    onClick={() => handleRowClick(asset)}
                    onContextMenu={(e) => handleContextMenu(e, asset, cat.id)}
                  >
                    <span className="sidebar-row-icon">{asset.icon}</span>
                    <div className="flex flex-col min-w-0 flex-1">
                      <span className="sidebar-row-text">{asset.name}</span>
                      {!isRoot && (
                        <span className="sidebar-row-subtitle">{relPath}</span>
                      )}
                    </div>
                    {asset.runStatus === 'done' && (
                      <span className="w-1.5 h-1.5 rounded-full bg-run-green shrink-0" title="Run complete" />
                    )}
                    {asset.runStatus === 'running' && (
                      <span className="w-1.5 h-1.5 rounded-full bg-run-orange shrink-0 animate-pulse" title="Running" />
                    )}
                  </div>
                )
              })}

              {catAssets.length === 0 && isOpen && !search && (
                <div className="px-3 py-2 text-[11px] text-text-tertiary italic">Empty</div>
              )}
            </div>
          )
        })}
      </div>

      {/* Status bar */}
      <div className="status-bar">
        <span className="status-indicator bg-run-green" />
        <span>{totalVisible} assets</span>
      </div>
    </div>
  )
}

function buildContextMenuItems(asset, category) {
  const items = []

  if (category === 'models') {
    const { useWorkbenchStore: getStore } = require('../stores/useWorkbenchStore')
    const store = getStore.getState()
    const runID = asset.runID
    const modFile = asset.path || asset.name

    if (runID) {
      items.push({
        label: 'Run NONMEM',
        icon: '▶️',
        action: () => {
          store.activateRun(modFile)
          setTimeout(() => store.runCommand(store.commandText), 50)
        },
      })
      items.push({ type: 'separator' })
      items.push({
        label: 'GOF Plot',
        icon: '📈',
        action: () => store.runGOF(runID, modFile),
      })
      items.push({
        label: 'VPC Plot',
        icon: '📉',
        action: () => store.runVPC(runID, modFile),
      })
      items.push({
        label: 'Individual Plot',
        icon: '👤',
        action: () => store.runIndividualPlot(runID, modFile),
      })
      items.push({ type: 'separator' })
      items.push({
        label: 'Full Diagnostics',
        icon: '🔬',
        action: () => store.runDiagnostics(runID, modFile),
      })
      items.push({
        label: 'AI Evaluate',
        icon: '🤖',
        action: () => {
          store.activateRun(modFile)
          store.runAudit(runID, modFile)
        },
      })
    }
  }

  if (category === 'outputs' && asset.name.endsWith('.lst')) {
    items.push({
      label: 'View in Detail',
      icon: '📄',
      action: () => {
        const store = require('../stores/useWorkbenchStore').useWorkbenchStore.getState()
        store.selectAsset(asset)
      },
    })
  }

  if (category === 'diagnostics' && (asset.name.endsWith('.png') || asset.name.endsWith('.jpg'))) {
    items.push({
      label: 'Open Image',
      icon: '🖼️',
      action: () => {
        const store = require('../stores/useWorkbenchStore').useWorkbenchStore.getState()
        store.selectAsset(asset)
      },
    })
  }

  if (items.length === 0) {
    items.push({
      label: 'Open',
      icon: '📂',
      action: () => {
        const store = require('../stores/useWorkbenchStore').useWorkbenchStore.getState()
        store.selectAsset(asset)
      },
    })
  }

  return items
}
