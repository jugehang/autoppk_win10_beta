import { create } from 'zustand'

// Asset category definitions — mirroring Swift AssetCategory
const assetCategories = [
  { id: 'models', title: 'Models', symbol: '📦', extensions: ['.mod', '.ctl'] },
  { id: 'datasets', title: 'Datasets', symbol: '📊', extensions: ['.csv', '.txt', '.dat'] },
  { id: 'outputs', title: 'Outputs', symbol: '📄', extensions: ['.lst', '.ext', '.cov', '.cor', '.coi', '.phi', '.shk', '.xml'] },
  { id: 'diagnostics', title: 'Diagnostics', symbol: '🔍', extensions: ['.pdf', '.png', '.jpg', '.html'] },
  { id: 'scripts', title: 'Scripts', symbol: '⚙️', extensions: ['.R', '.py', '.sh'] },
  { id: 'reports', title: 'Reports', symbol: '📝', extensions: ['.md'] },
  { id: 'other', title: 'Other', symbol: '📁', extensions: [] },
]

const FILE_ICONS = {
  '.mod': '🟦', '.ctl': '🟦',
  '.csv': '📊', '.txt': '📊', '.dat': '📊',
  '.lst': '📄', '.ext': '📋', '.cov': '📋', '.cor': '📋', '.phi': '📋', '.shk': '📋', '.xml': '📄',
  '.pdf': '🔴', '.png': '🖼️', '.jpg': '🖼️', '.html': '🌐',
  '.R': '🔵', '.py': '🟡', '.sh': '🟢',
  '.md': '📝',
}

function getCategory(filename) {
  const ext = '.' + filename.split('.').pop()?.toLowerCase()
  for (const cat of assetCategories) {
    if (cat.extensions.includes(ext)) return cat.id
  }
  return 'other'
}

function getFileIcon(filename) {
  const ext = '.' + filename.split('.').pop()?.toLowerCase()
  return FILE_ICONS[ext] || '📄'
}

function parseRunID(filename) {
  const lower = filename.toLowerCase()
  if (lower.startsWith('ga') && lower.endsWith('.mod')) {
    const id = filename.slice(2, -4)
    if (/^\d+$/.test(id)) return id
  }
  if (!lower.startsWith('run') || !lower.endsWith('.mod')) return null
  let id = filename.slice(3, -4).replace(/_ga_opt$/, '')
  if (/^\d+$/.test(id)) return id
  const match = id.match(/(\d+)(?!.*\d)/)
  if (match) return match[1]
  return id || null
}

function getRunStatus(filename, siblings) {
  const base = filename.replace(/\.(mod|ctl)$/, '')
  const hasLst = siblings.some(s => s.name === base + '.lst')
  const hasExt = siblings.some(s => s.name === base + '.ext')
  const hasCov = siblings.some(s => s.name === base + '.cov')
  if (hasLst && hasExt && hasCov) return 'done'
  if (hasLst) return 'running'
  return 'idle'
}

function scanAssets(files) {
  const result = {}
  for (const cat of assetCategories) {
    result[cat.id] = []
  }
  for (const file of files) {
    const catId = getCategory(file.name)
    const modId = parseRunID(file.name)
    const icon = getFileIcon(file.name)
    result[catId].push({
      ...file,
      category: catId,
      icon,
      runID: modId,
      runStatus: file.name.endsWith('.mod') ? getRunStatus(file.name, files) : null,
    })
  }
  // Sort within each category
  for (const cat of assetCategories) {
    result[cat.id].sort((a, b) => a.name.localeCompare(b.name))
  }
  return result
}

// ============================================
// Zustand Store — mirrors WorkbenchStore
// ============================================

const useWorkbenchStore = create((set, get) => ({
  // Project
  projectDir: null,
  projectName: '',
  assets: {},
  selectedAsset: null,
  selectedCategory: 'models',
  fileContent: null,
  parameters: [],

  // Run state
  currentRun: null,
  commandText: '',
  isRunning: false,

  // Terminal
  terminalOutput: [],

  // AI Assistant
  showAI: false,
  aiMessages: [],
  aiLoading: false,

  // Settings
  settings: {
    llmProvider: 'openai',
    openaiKey: '',
    openaiModel: 'gpt-4o',
    openaiEndpoint: 'https://api.openai.com/v1',
    deepseekKey: '',
    deepseekModel: 'deepseek-chat',
    deepseekEndpoint: 'https://api.deepseek.com/v1',
    rscriptPath: 'Rscript',
    pythonPath: 'python3',
  },
  showSettings: false,

  // Context menu
  contextMenu: null,

  // ========================================
  // Project Actions
  // ========================================

  setProject: (dir) => {
    const name = dir.split('/').pop() || dir.split('\\').pop() || 'Untitled'
    set({ projectDir: dir, projectName: name })
  },

  loadAssets: async () => {
    const { projectDir } = get()
    if (!projectDir) return
    try {
      const { default: api } = await import('../services/api')
      const data = await api.scanProject(projectDir)
      const assets = scanAssets(data.files || [])
      set({ assets })
    } catch (e) {
      console.error('Scan failed:', e)
    }
  },

  selectAsset: async (asset) => {
    set({ selectedAsset: asset, fileContent: null, parameters: [] })
    if (!asset) return
    const { projectDir } = get()
    try {
      const { default: api } = await import('../services/api')
      if (asset.category === 'models') {
        const params = await api.getParameters(projectDir, asset.path || asset.name)
        set({ parameters: params.parameters || [] })
      }
      const content = await api.getFileContent(projectDir, asset.path || asset.name)
      set({ fileContent: content.content || content.text || '' })
    } catch (e) {
      console.error('Load file failed:', e)
    }
  },

  setSelectedCategory: (catId) => set({ selectedCategory: catId }),

  // ========================================
  // Run Actions
  // ========================================

  activateRun: async (modFileName) => {
    const dummyName = modFileName.split('/').pop() || modFileName
    const runID = parseRunID(dummyName) || dummyName.replace(/^run/, '').replace(/\.mod$/, '')
    set({
      currentRun: runID,
      commandText: `execute ${dummyName} -model_dir_name`,
    })
  },

  runCommand: async (command) => {
    const { projectDir } = get()
    if (!projectDir || !command) return
    set({ isRunning: true, terminalOutput: [...get().terminalOutput, { type: 'info', text: `$ ${command}` }] })
    try {
      const { default: api } = await import('../services/api')
      const result = await api.runCommand(projectDir, command)
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stdout', text: result.output || 'Done.' }],
        isRunning: false,
      }))
    } catch (e) {
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stderr', text: `Error: ${e.message}` }],
        isRunning: false,
      }))
    }
  },

  runGOF: async (runId, modFile) => {
    const { projectDir } = get()
    set({ isRunning: true })
    try {
      const { default: api } = await import('../services/api')
      const result = await api.runGOF(projectDir, runId, modFile)
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stdout', text: result.output || 'GOF complete.' }],
        isRunning: false,
      }))
      get().loadAssets()
    } catch (e) {
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stderr', text: `GOF Error: ${e.message}` }],
        isRunning: false,
      }))
    }
  },

  runVPC: async (runId, modFile) => {
    const { projectDir } = get()
    set({ isRunning: true })
    try {
      const { default: api } = await import('../services/api')
      const result = await api.runVPC(projectDir, runId, modFile)
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stdout', text: result.output || 'VPC complete.' }],
        isRunning: false,
      }))
      get().loadAssets()
    } catch (e) {
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stderr', text: `VPC Error: ${e.message}` }],
        isRunning: false,
      }))
    }
  },

  runIndividualPlot: async (runId, modFile) => {
    const { projectDir } = get()
    set({ isRunning: true })
    try {
      const { default: api } = await import('../services/api')
      const result = await api.runIndividualPlot(projectDir, runId, modFile)
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stdout', text: result.output || 'Individual plot complete.' }],
        isRunning: false,
      }))
      get().loadAssets()
    } catch (e) {
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stderr', text: `Plot Error: ${e.message}` }],
        isRunning: false,
      }))
    }
  },

  runDiagnostics: async (runId, modFile) => {
    const { projectDir } = get()
    set({ isRunning: true })
    try {
      const { default: api } = await import('../services/api')
      const result = await api.runDiagnostics(projectDir, runId, modFile)
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stdout', text: result.output || 'Diagnostics complete.' }],
        isRunning: false,
      }))
      get().loadAssets()
    } catch (e) {
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stderr', text: `Diagnostics Error: ${e.message}` }],
        isRunning: false,
      }))
    }
  },

  runAudit: async (runId, modFile) => {
    const { projectDir, settings } = get()
    set({ isRunning: true, terminalOutput: [...get().terminalOutput, { type: 'info', text: `Running AI audit for run${runId}...` }] })
    try {
      const { default: api } = await import('../services/api')
      const result = await api.runAudit(projectDir, runId, modFile, settings.llmProvider, settings.openaiKey || settings.deepseekKey)
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stdout', text: result.report || result.output || 'Audit complete.' }],
        isRunning: false,
      }))
    } catch (e) {
      set(state => ({
        terminalOutput: [...state.terminalOutput, { type: 'stderr', text: `Audit Error: ${e.message}` }],
        isRunning: false,
      }))
    }
  },

  // ========================================
  // AI Chat
  // ========================================

  toggleAI: () => set(s => ({ showAI: !s.showAI })),

  addAIMessage: (role, content) => {
    set(s => ({ aiMessages: [...s.aiMessages, { role, content, timestamp: Date.now() }] }))
  },

  setAILoading: (v) => set({ aiLoading: v }),

  clearAIChat: () => set({ aiMessages: [] }),

  // ========================================
  // Settings
  // ========================================

  toggleSettings: () => set(s => ({ showSettings: !s.showSettings })),
  updateSettings: (partial) => set(s => ({ settings: { ...s.settings, ...partial } })),

  // ========================================
  // Context Menu
  // ========================================

  showContextMenu: (x, y, items) => set({ contextMenu: { x, y, items } }),
  dismissContextMenu: () => set({ contextMenu: null }),
}))

export { useWorkbenchStore, assetCategories, parseRunID, getFileIcon, getCategory, getRunStatus }
export default useWorkbenchStore
