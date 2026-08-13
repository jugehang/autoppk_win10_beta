import { useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import GlassNav from "./components/GlassNav";

const TEMPLATES: { id: string; label: string }[] = [
  { id: "iv_infusion_1c_advan1_trans2", label: "IV Infusion 1-cmt" },
  { id: "iv_infusion_2c_advan3_trans4", label: "IV Infusion 2-cmt" },
  { id: "iv_bolus_1c_advan1_trans2", label: "IV Bolus 1-cmt" },
  { id: "iv_bolus_2c_advan3_trans4", label: "IV Bolus 2-cmt" },
  { id: "extravascular_1c_advan2_trans2", label: "Extravascular 1-cmt" },
  { id: "extravascular_2c_advan4_trans4", label: "Extravascular 2-cmt" },
];

export default function App() {
  const [active, setActive] = useState("demo-mab");
  const [platform, setPlatform] = useState("…");
  const [template, setTemplate] = useState(TEMPLATES[1].id);
  const [modelText, setModelText] = useState("");
  const [error, setError] = useState("");
  const [rendering, setRendering] = useState(false);
  const [glassOn, setGlassOn] = useState(true);

  useEffect(() => {
    invoke<string>("get_platform")
      .then(setPlatform)
      .catch((e) => setPlatform(String(e)));
  }, []);

  useEffect(() => {
    document.body.dataset.glass = glassOn ? "on" : "off";
  }, [glassOn]);

  async function renderModel() {
    setRendering(true);
    setError("");
    setModelText("");
    try {
      const text = await invoke<string>("render_model_template", {
        template,
        run: "001",
      });
      setModelText(text);
    } catch (e) {
      setError(String(e));
    } finally {
      setRendering(false);
    }
  }

  return (
    <div className="app">
      <GlassNav active={active} onSelect={setActive} />

      <main className="main" data-tauri-drag-region>
        <header className="topbar">
          <div className="topbar__title" data-tauri-drag-region>
            <h1>PopPK 建模工作台</h1>
            <p className="topbar__sub">AutoPMX · PopPK 自动化建模平台</p>
          </div>
          <div className="topbar__actions">
            <span className="pill" title="当前平台">
              {platform}
            </span>
            <button
              type="button"
              className="pill pill--toggle"
              onClick={() => setGlassOn((v) => !v)}
              aria-pressed={glassOn}
            >
              {glassOn ? "毛玻璃：开" : "毛玻璃：关"}
            </button>
          </div>
        </header>

        <section className="cards">
          <article className="glass card card--project">
            <h2 className="card__title">当前项目</h2>
            <p className="card__desc">
              <strong>Demo_mAb_Run41</strong> — ADVAN13 双室母药+代谢产物模型，
              当前 run32。
            </p>
            <dl className="stats">
              <div>
                <dt>最新 Run</dt>
                <dd>32</dd>
              </div>
              <div>
                <dt>结构</dt>
                <dd>3-cmt ADVAN13</dd>
              </div>
              <div>
                <dt>观测</dt>
                <dd>CP + CM</dd>
              </div>
            </dl>
          </article>

          <article className="glass card card--render">
            <h2 className="card__title">模型生成</h2>
            <p className="card__desc">
              从 PopPK 模型库模板生成 NONMEM 控制流，作为自动建模的起点。
            </p>
            <div className="render-controls">
              <label className="field">
                <span>模板</span>
                <select
                  value={template}
                  onChange={(e) => setTemplate(e.target.value)}
                >
                  {TEMPLATES.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.label}
                    </option>
                  ))}
                </select>
              </label>
              <button
                type="button"
                className="btn"
                onClick={renderModel}
                disabled={rendering}
              >
                {rendering ? "生成中…" : "生成模型"}
              </button>
            </div>

            {error && (
              <pre className="error" role="alert">
                {error}
              </pre>
            )}
            {modelText && (
              <pre className="model-out" tabIndex={0} aria-label="生成的模型">
                {modelText}
              </pre>
            )}
          </article>
        </section>
      </main>
    </div>
  );
}
