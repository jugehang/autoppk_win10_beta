import React, { useEffect, useRef } from 'react'
import useWorkbenchStore from '../stores/useWorkbenchStore'

export default function ContextMenu() {
  const { contextMenu, dismissContextMenu } = useWorkbenchStore()
  const menuRef = useRef(null)

  useEffect(() => {
    if (!contextMenu) return

    const handleClick = () => dismissContextMenu()
    const handleKey = (e) => { if (e.key === 'Escape') dismissContextMenu() }

    document.addEventListener('click', handleClick)
    document.addEventListener('keydown', handleKey)
    return () => {
      document.removeEventListener('click', handleClick)
      document.removeEventListener('keydown', handleKey)
    }
  }, [contextMenu, dismissContextMenu])

  if (!contextMenu) return null

  const { x, y, items } = contextMenu

  // Adjust position to stay in viewport
  const menuWidth = 200
  const menuHeight = items.length * 32 + 16
  const adjustedX = Math.min(x, window.innerWidth - menuWidth - 8)
  const adjustedY = Math.min(y, window.innerHeight - menuHeight - 8)

  return (
    <div
      ref={menuRef}
      className="context-menu"
      style={{ left: adjustedX, top: adjustedY }}
    >
      {items.map((item, i) => {
        if (item.type === 'separator') {
          return <div key={i} className="context-menu-separator" />
        }
        return (
          <div
            key={i}
            className={`context-menu-item ${item.destructive ? 'destructive' : ''}`}
            onClick={(e) => {
              e.stopPropagation()
              item.action?.()
              dismissContextMenu()
            }}
          >
            <span className="text-[13px] w-5 text-center">{item.icon}</span>
            <span>{item.label}</span>
          </div>
        )
      })}
    </div>
  )
}
