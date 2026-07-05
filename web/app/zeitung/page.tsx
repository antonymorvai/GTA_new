'use client';

import { useEffect, useState } from 'react';

interface Article {
  id: number; headline: string; body: string; published_at: string;
  first_name: string; last_name: string;
}

export default function NewsPage() {
  const [articles, setArticles] = useState<Article[]>([]);

  useEffect(() => {
    fetch('/api/v1/public/news')
      .then((r) => (r.ok ? r.json() : []))
      .then(setArticles)
      .catch(() => undefined);
  }, []);

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <h1 className="text-2xl font-semibold text-white">📰 Weazel News</h1>
      {articles.map((a) => (
        <article key={a.id} className="panel">
          <h2 className="font-semibold text-white text-lg">{a.headline}</h2>
          <p className="text-xs text-gray-500 mt-1">
            von {a.first_name} {a.last_name} · {new Date(a.published_at).toLocaleString('de-DE')}
          </p>
          <p className="text-sm text-gray-300 mt-3 whitespace-pre-wrap">{a.body}</p>
        </article>
      ))}
      {articles.length === 0 && (
        <p className="text-gray-500 text-sm">Noch keine Artikel — die Redaktion schläft nie lange.</p>
      )}
    </div>
  );
}
