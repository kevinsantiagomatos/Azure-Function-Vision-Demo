import { useEffect, useMemo, useState } from 'react'
import './App.css'

const API_BASE = import.meta.env.VITE_API_BASE || ''

function App() {
  const [items, setItems] = useState([])
  const [tagFilter, setTagFilter] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const apiUrl = useMemo(() => {
    const url = new URL(`${API_BASE}/api/list`, window.location.origin)
    if (tagFilter) url.searchParams.set('tag', tagFilter)
    url.searchParams.set('limit', '100')
    return url.toString()
  }, [tagFilter])

  useEffect(() => {
    let active = true
    async function fetchData() {
      try {
        setLoading(true)
        setError(null)
        const res = await fetch(apiUrl)
        if (!res.ok) throw new Error(`Request failed: ${res.status}`)
        const body = await res.json()
        if (active) setItems(body.items ?? [])
      } catch (e) {
        if (active) setError(e.message)
      } finally {
        if (active) setLoading(false)
      }
    }
    fetchData()
    return () => {
      active = false
    }
  }, [apiUrl])

  return (
    <div className="page">
      <header className="hero">
        <div>
          <p className="eyebrow">Azure Serverless Image Pipeline</p>
          <h1>Vision-tagged gallery</h1>
          <p className="lede">
            Upload images to Blob Storage and see thumbnails, AI-generated tags, and captions pulled from Cosmos DB through a Functions API.
          </p>
        </div>
        <div className="filters">
          <label htmlFor="tag">Filter by tag</label>
          <input
            id="tag"
            value={tagFilter}
            onChange={(e) => setTagFilter(e.target.value)}
            placeholder="e.g. cat, beach"
          />
        </div>
      </header>

      {loading && <p className="status">Loading…</p>}
      {error && <p className="status error">Error: {error}</p>}
      {!loading && items.length === 0 && <p className="status">No images yet. Upload to the `images` container to populate the feed.</p>}

      <section className="grid">
        {items.map((item) => (
          <article className="card" key={item.id}>
            <img src={item.thumbnail_url || item.image_url} alt={item.caption || item.filename} />
            <div className="card-body">
              <p className="caption">{item.caption || 'No caption yet'}</p>
              <p className="filename">{item.filename}</p>
              {item.tags?.length ? (
                <div className="tags">
                  {item.tags.map((t) => (
                    <span className="tag" key={t}>{t}</span>
                  ))}
                </div>
              ) : (
                <p className="muted">No tags</p>
              )}
              <a className="link" href={item.image_url} target=\"_blank\" rel=\"noreferrer\">Open original</a>
            </div>
          </article>
        ))}
      </section>
    </div>
  )
}

export default App
