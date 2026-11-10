/** Dedupe late and out-of-order messages without retaining every sequence number. */
export const createSequenceHistory = () => {
  const ranges: [number, number][] = [];

  return (sequence: number) => {
    if (!Number.isSafeInteger(sequence)) {
      return true;
    }

    let index = ranges.length;
    while (index > 0 && ranges[index - 1][0] > sequence) {
      index--;
    }

    const previous = ranges[index - 1];
    const next = ranges[index];
    if (previous && sequence <= previous[1]) {
      return false;
    }

    if (previous && previous[1] + 1 === sequence) {
      previous[1] = sequence;
      if (next && next[0] === sequence + 1) {
        previous[1] = next[1];
        ranges.splice(index, 1);
      }
    } else if (next && next[0] === sequence + 1) {
      next[0] = sequence;
    } else {
      ranges.splice(index, 0, [sequence, sequence]);
    }
    return true;
  };
};
