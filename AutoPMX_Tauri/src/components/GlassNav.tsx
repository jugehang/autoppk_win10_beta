import { useState } from "react";

interface NavSection {
  title: string;
  items: { id: string; label: string; badge?: string }[];
}

const SECTIONS: NavSection[] = [
  {
    title: "项目",
    items: [
      { id: "demo-mab", label: "Demo_mAb_Run41", badge: "run32" },
      { id: "scm-demo", label: "SCM_Demo_Covariate" },
    ],
  },
  {
    title: "工作台",
    items: [
      { id: "eda", label: "EDA 探索" },
      { id: "base", label: "基模筛选" },
      { id: "scm", label: "协变量筛选" },
      { id: "vpc", label: "VPC 验证" },
      { id: "reports", label: "报告" },
    ],
  },
];

export default function GlassNav({
  active,
  onSelect,
}: {
  active: string;
  onSelect: (id: string) => void;
}) {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <nav
      className="glass sidebar"
      aria-label="主导航"
      data-tauri-drag-region
    >
      <div className="sidebar__brand" data-tauri-drag-region>
        <span className="sidebar__logo" aria-hidden="true">
          ◈
        </span>
        {!collapsed && <strong>AutoPMX</strong>}
      </div>

      <button
        type="button"
        className="sidebar__collapse"
        onClick={() => setCollapsed((v) => !v)}
        aria-label={collapsed ? "展开侧栏" : "折叠侧栏"}
      >
        {collapsed ? "»" : "«"}
      </button>

      {SECTIONS.map((section) => (
        <section key={section.title} className="sidebar__section">
          {!collapsed && (
            <h2 className="sidebar__heading">{section.title}</h2>
          )}
          <ul className="sidebar__list">
            {section.items.map((item) => (
              <li key={item.id}>
                <button
                  type="button"
                  className={
                    "sidebar__item" + (active === item.id ? " is-active" : "")
                  }
                  onClick={() => onSelect(item.id)}
                  aria-current={active === item.id ? "page" : undefined}
                  title={collapsed ? item.label : undefined}
                >
                  <span className="sidebar__item-label">{item.label}</span>
                  {item.badge && !collapsed && (
                    <span className="sidebar__badge">{item.badge}</span>
                  )}
                </button>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </nav>
  );
}
