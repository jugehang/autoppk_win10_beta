const BASE = '/api'

async function request(path, options = {}) {
  const url = `${BASE}${path}`
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }))
    throw new Error(err.detail || `HTTP ${res.status}`)
  }
  return res.json()
}

// Project
export async function scanProject(projectDir) {
  return request(`/project/scan?dir=${encodeURIComponent(projectDir)}`)
}

export async function getFileContent(projectDir, filePath) {
  return request(`/project/file?dir=${encodeURIComponent(projectDir)}&path=${encodeURIComponent(filePath)}`)
}

export async function getParameters(projectDir, modPath) {
  return request(`/project/parameters?dir=${encodeURIComponent(projectDir)}&mod=${encodeURIComponent(modPath)}`)
}

// Execution
export async function runCommand(projectDir, command) {
  return request(`/run`, {
    method: 'POST',
    body: JSON.stringify({ projectDir, command }),
  })
}

export async function runGOF(projectDir, runId, modFile) {
  return request(`/run/gof`, {
    method: 'POST',
    body: JSON.stringify({ projectDir, runId, modFile }),
  })
}

export async function runVPC(projectDir, runId, modFile) {
  return request(`/run/vpc`, {
    method: 'POST',
    body: JSON.stringify({ projectDir, runId, modFile }),
  })
}

export async function runIndividualPlot(projectDir, runId, modFile) {
  return request(`/run/individual`, {
    method: 'POST',
    body: JSON.stringify({ projectDir, runId, modFile }),
  })
}

export async function runDiagnostics(projectDir, runId, modFile) {
  return request(`/run/diagnostics`, {
    method: 'POST',
    body: JSON.stringify({ projectDir, runId, modFile }),
  })
}

export async function runAudit(projectDir, runId, modFile, provider, apiKey) {
  return request(`/run/audit`, {
    method: 'POST',
    body: JSON.stringify({ projectDir, runId, modFile, provider, apiKey }),
  })
}

// AI Chat
export async function sendChatMessage(messages, providerSettings) {
  return request(`/chat`, {
    method: 'POST',
    body: JSON.stringify({ messages, ...providerSettings }),
  })
}

export async function sendChatMessageStream(messages, providerSettings) {
  const url = `${BASE}/chat/stream`
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ messages, ...providerSettings }),
  })
  if (!res.ok) throw new Error(`Chat stream error: ${res.status}`)
  return res.body
}

// Settings
export async function getSettings() {
  return request(`/settings`)
}

export async function saveSettings(settings) {
  return request(`/settings`, {
    method: 'PUT',
    body: JSON.stringify(settings),
  })
}
