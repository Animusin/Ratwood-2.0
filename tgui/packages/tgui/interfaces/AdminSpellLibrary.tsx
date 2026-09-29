import { useMemo, useState } from 'react';
import { Box, Button, Icon, Input, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Spell = {
  path: string;
  name: string;
  desc: string;
  category: string;
  icon: string;
  cooldown: number;
  charge_time: number;
};

type Data = {
  spells: Spell[];
  categories: { id: string; name: string }[];
  target_name: string;
  target_key?: string;
  target_valid: boolean;
  mindless: boolean;
  known_spells: Record<string, boolean>;
  status_message?: string;
};

const PAGE_SIZE = 24;
const categoryIcons: Record<string, string> = {
  attack: 'bolt',
  healing: 'heart',
  protection: 'shield-alt',
  summoning: 'hat-wizard',
  movement: 'running',
  buff: 'star',
  control: 'hand-paper',
  other: 'book',
};

export const AdminSpellLibrary = () => {
  const { act, data } = useBackend<Data>();
  const {
    spells = [],
    categories = [],
    known_spells = {},
    target_name,
    target_key,
    target_valid,
    mindless,
    status_message,
  } = data;
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('all');
  const [ownership, setOwnership] = useState<'all' | 'known' | 'unknown'>(
    'all',
  );
  const [page, setPage] = useState(1);

  const matched = useMemo(() => {
    const query = search.trim().toLowerCase();
    return spells
      .filter(
        (spell) =>
          (ownership === 'all' ||
            (ownership === 'known'
              ? !!known_spells[spell.path]
              : !known_spells[spell.path])) &&
          (!query ||
            `${spell.name} ${spell.desc} ${spell.path}`
              .toLowerCase()
              .includes(query)),
      )
      .sort(
        (a, b) => a.name.localeCompare(b.name) || a.path.localeCompare(b.path),
      );
  }, [spells, search, ownership, known_spells]);
  const filtered = matched.filter(
    (spell) => category === 'all' || spell.category === category,
  );
  const pages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const currentPage = Math.min(page, pages);
  const visible = filtered.slice(
    (currentPage - 1) * PAGE_SIZE,
    currentPage * PAGE_SIZE,
  );

  return (
    <Window title="Выдача заклинаний" width={1080} height={760} theme="dark">
      <Window.Content className="AdminSpellLibrary">
        <Stack vertical fill>
          <Stack.Item>
            <Section>
              <Stack align="center">
                <Stack.Item>
                  <Icon name="hat-wizard" size={2} color="#00e1ff" />
                </Stack.Item>
                <Stack.Item grow>
                  <Box color="label" fontSize="0.85em">
                    Получатель
                  </Box>
                  <Box bold fontSize="1.2em">
                    {target_name}
                    {target_key ? ` (${target_key})` : ''}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Stack vertical>
                    <Stack.Item>
                      <Button.Checkbox
                        checked={ownership === 'known'}
                        onClick={() => {
                          setOwnership(ownership === 'known' ? 'all' : 'known');
                          setPage(1);
                        }}
                      >
                        Только имеющиеся
                      </Button.Checkbox>
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        checked={ownership === 'unknown'}
                        onClick={() => {
                          setOwnership(
                            ownership === 'unknown' ? 'all' : 'unknown',
                          );
                          setPage(1);
                        }}
                      >
                        Скрыть имеющиеся
                      </Button.Checkbox>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
              {!!mindless && (
                <Box color="average" mt={1}>
                  У цели нет разума: способности останутся привязаны к этому
                  телу.
                </Box>
              )}
              {!target_valid && (
                <Box color="bad" mt={1}>
                  Получатель изменился или был удалён. Откройте выдачу заново.
                </Box>
              )}
              {status_message && (
                <Box mt={1} color="label">
                  {status_message}
                </Box>
              )}
              <Box mt={1}>
                <Input
                  fluid
                  placeholder="Поиск по названию, описанию или пути..."
                  value={search}
                  onChange={(value) => {
                    setSearch(value);
                    setPage(1);
                  }}
                />
              </Box>
            </Section>
          </Stack.Item>
          <Stack.Item grow className="AdminSpellLibrary__body">
            <Stack fill>
              <Stack.Item width="175px">
                <Section title="Назначение" fill scrollable>
                  {[{ id: 'all', name: 'Все заклинания' }, ...categories].map(
                    (item) => (
                      <Button
                        key={item.id}
                        fluid
                        mb={0.5}
                        icon={categoryIcons[item.id] || 'book-open'}
                        selected={category === item.id}
                        onClick={() => {
                          setCategory(item.id);
                          setPage(1);
                        }}
                      >
                        {item.name} (
                        {item.id === 'all'
                          ? matched.length
                          : matched.filter(
                              (spell) => spell.category === item.id,
                            ).length}
                        )
                      </Button>
                    ),
                  )}
                </Section>
              </Stack.Item>
              <Stack.Item grow className="AdminSpellLibrary__body">
                <Stack vertical fill>
                  <Stack.Item>
                    <Stack align="center">
                      <Stack.Item grow>Найдено: {filtered.length}</Stack.Item>
                      <Stack.Item>
                        <Button
                          icon="chevron-left"
                          disabled={currentPage <= 1}
                          onClick={() => setPage(currentPage - 1)}
                          tooltip="Предыдущая страница"
                        />
                        <Box inline mx={1}>
                          {currentPage} / {pages}
                        </Box>
                        <Button
                          icon="chevron-right"
                          disabled={currentPage >= pages}
                          onClick={() => setPage(currentPage + 1)}
                          tooltip="Следующая страница"
                        />
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                  <Stack.Item grow className="AdminSpellLibrary__results">
                    {!visible.length && (
                      <Section>
                        Заклинания не найдены. Измените поиск или категорию.
                      </Section>
                    )}
                    <div className="AdminSpellLibrary__grid">
                      {visible.map((spell) => {
                        const known = !!known_spells[spell.path];
                        return (
                          <article
                            key={spell.path}
                            className={`AdminSpellLibrary__card${known ? ' AdminSpellLibrary__card--known' : ''}`}
                          >
                            <div className="AdminSpellLibrary__spell-heading">
                              <div
                                className="AdminSpellLibrary__icon"
                                aria-hidden="true"
                              >
                                <span className={spell.icon} />
                              </div>
                              <div>
                                <div className="AdminSpellLibrary__name">
                                  {spell.name}
                                </div>
                                <Box color="label" fontSize="0.85em">
                                  {
                                    categories.find(
                                      (item) => item.id === spell.category,
                                    )?.name
                                  }
                                </Box>
                              </div>
                            </div>
                            <div className="AdminSpellLibrary__description">
                              {spell.desc ||
                                'Для этого заклинания описание не задано.'}
                            </div>
                            <div className="AdminSpellLibrary__stats">
                              {spell.charge_time > 0 && (
                                <span>Подготовка: {spell.charge_time} с</span>
                              )}
                              {spell.cooldown > 0 && (
                                <span>Перезарядка: {spell.cooldown} с</span>
                              )}
                            </div>
                            <details className="AdminSpellLibrary__path">
                              <summary>Путь заклинания</summary>
                              {spell.path}
                            </details>
                            <Button
                              fluid
                              icon={known ? 'check' : 'plus'}
                              color={known ? 'default' : 'good'}
                              disabled={known || !target_valid}
                              onClick={() => act('grant', { path: spell.path })}
                            >
                              {known ? 'Уже имеется' : 'Выдать'}
                            </Button>
                            {known && (
                              <Button
                                fluid
                                mt={0.5}
                                icon="minus"
                                color="bad"
                                disabled={!target_valid}
                                onClick={() =>
                                  act('revoke', { path: spell.path })
                                }
                              >
                                Забрать заклинание
                              </Button>
                            )}
                          </article>
                        );
                      })}
                    </div>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
