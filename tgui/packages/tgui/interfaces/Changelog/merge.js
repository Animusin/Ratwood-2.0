// Merge dated archives without losing authors or repeating an upstreamed local entry.
export const mergeChangelog = (documents) => {
  const days = new Map();
  for (const document of documents) {
    for (const [date, authors] of Object.entries(document || {})) {
      if (!days.has(date)) {
        days.set(date, new Map());
      }
      const mergedAuthors = days.get(date);
      for (const [author, changes] of Object.entries(authors)) {
        if (!mergedAuthors.has(author)) {
          mergedAuthors.set(author, []);
        }
        const entries = mergedAuthors.get(author);
        for (const change of changes) {
          if (
            !entries.some(
              (entry) => JSON.stringify(entry) === JSON.stringify(change),
            )
          ) {
            entries.push(change);
          }
        }
      }
    }
  }
  return Object.fromEntries(
    [...days.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, authors]) => [date, Object.fromEntries(authors)]),
  );
};
