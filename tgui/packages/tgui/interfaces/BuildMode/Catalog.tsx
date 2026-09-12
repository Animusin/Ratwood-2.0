import {
  Box,
  Button,
  Dropdown,
  Input,
  NumberInput,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../../backend';
import { type BuildModeData, type CatalogOption, Sprite } from './common';

export const CatalogSidebar = () => {
  const { act, data } = useBackend<BuildModeData>();
  const counts: Record<string, number> = {
    ...data.counts,
    all: data.total,
    favorites: data.favorites_count,
    recent: data.recent_count,
  };
  return (
    <nav className="BuildMode__sidebar">
      {data.categories.map(({ id, name }) => (
        <Button
          key={id}
          fluid
          tooltip={name}
          selected={data.category === id}
          className="BuildMode__category"
          onClick={() => act('category', { value: id })}
        >
          <span className="BuildMode__category-name">{name}</span>
          <span className="BuildMode__count">{counts[id] || 0}</span>
        </Button>
      ))}
    </nav>
  );
};

export const CatalogBrowser = () => {
  const { act, data } = useBackend<BuildModeData>();
  return (
    <main className="BuildMode__catalog">
      <Stack align="center" mb={1}>
        <Stack.Item grow>
          <Input
            fluid
            autoFocus
            expensive
            maxLength={data.max_search_length}
            value={data.search}
            placeholder="Имя или /путь…"
            onChange={(value) => act('search', { value })}
            onEnter={(value) => act('search', { value })}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="times"
            tooltip="Очистить поиск"
            disabled={!data.search}
            onClick={() => act('search', { value: '' })}
          />
        </Stack.Item>
      </Stack>
      <CatalogFilters />
      <Box className="BuildMode__results-label">
        {data.categories.find(({ id }) => id === data.category)?.name} · найдено{' '}
        {data.matches}
      </Box>
      <CatalogPagination />
      <CatalogResults />
    </main>
  );
};

const CatalogFilter = ({
  selected,
  options,
  onSelected,
}: {
  selected: string;
  options: CatalogOption[];
  onSelected: (value: string) => void;
}) => (
  <Dropdown
    fluid
    selected={selected}
    options={options.map(({ id, name }) => ({ value: id, displayText: name }))}
    displayText={options.find(({ id }) => id === selected)?.name}
    onSelected={onSelected}
  />
);

const CatalogFilters = () => {
  const { act, data } = useBackend<BuildModeData>();
  return (
    <>
      {data.subcategories?.length > 1 && (
        <div className="BuildMode__filters">
          <CatalogFilter
            selected={data.subcategory}
            options={data.subcategories}
            onSelected={(value) => act('subcategory', { value })}
          />
        </div>
      )}
      {data.category === 'clothing' && (
        <div className="BuildMode__filters">
          <CatalogFilter
            selected={data.armor_class}
            options={data.armor_classes}
            onSelected={(value) => act('armor_class', { value })}
          />
          <CatalogFilter
            selected={data.coverage}
            options={data.coverage_zones}
            onSelected={(value) => act('coverage', { value })}
          />
        </div>
      )}
    </>
  );
};

const CatalogPagination = () => {
  const { act, data } = useBackend<BuildModeData>();
  return (
    <div className="BuildMode__pagination" aria-label="Страницы каталога">
      <Button
        tooltip="Первая страница"
        disabled={data.page <= 1}
        onClick={() => act('page', { value: 1 })}
      >
        «
      </Button>
      <Button
        disabled={data.page <= 1}
        onClick={() => act('page', { value: data.page - 1 })}
      >
        ‹<span className="BuildMode__page-label"> Назад</span>
      </Button>
      <div className="BuildMode__page-number">
        <NumberInput
          value={data.page}
          minValue={1}
          maxValue={data.pages}
          step={1}
          width="54px"
          onChange={(value) => act('page', { value })}
        />
        <span>/ {data.pages}</span>
      </div>
      <Button
        iconPosition="right"
        disabled={data.page >= data.pages}
        onClick={() => act('page', { value: data.page + 1 })}
      >
        <span className="BuildMode__page-label">Далее </span>›
      </Button>
      <Button
        tooltip="Последняя страница"
        disabled={data.page >= data.pages}
        onClick={() => act('page', { value: data.pages })}
      >
        »
      </Button>
    </div>
  );
};

const CatalogResults = () => {
  const { act, data } = useBackend<BuildModeData>();
  const selected = data.selected;
  return (
    <div
      className="BuildMode__results"
      key={`${data.category}:${data.subcategory}:${data.armor_class}:${data.coverage}:${data.page}:${data.search}`}
    >
      {data.items.length ? (
        <div className="BuildMode__grid">
          {data.items.map((item) => (
            <div
              key={item.path}
              className={`BuildMode__card${selected?.path === item.path ? ' BuildMode__card--selected' : ''}`}
            >
              <Button
                className="BuildMode__pick"
                color="transparent"
                fluid
                selected={selected?.path === item.path}
                tooltip={item.path}
                onClick={() => act('select', { path: item.path })}
              >
                <Sprite item={item} />
                <div className="BuildMode__name">{item.name}</div>
                <div className="BuildMode__variant">
                  {item.path.split('/').slice(-2).join('/')}
                </div>
              </Button>
              <Button
                className={`BuildMode__star${item.favorite ? ' BuildMode__star--saved' : ''}`}
                icon="star"
                color={item.favorite ? 'gold' : 'transparent'}
                tooltip={item.favorite ? 'Убрать из избранного' : 'В избранное'}
                onClick={() => act('favorite', { path: item.path })}
              />
            </div>
          ))}
        </div>
      ) : (
        <div className="BuildMode__empty">
          <Box fontSize="18px" mb={1}>
            {data.category === 'favorites'
              ? 'Избранное пусто'
              : data.category === 'recent'
                ? 'История пуста'
                : 'Ничего не найдено'}
          </Box>
          {data.search && (
            <Button mt={1} onClick={() => act('category', { value: 'all' })}>
              Искать везде
            </Button>
          )}
        </div>
      )}
    </div>
  );
};
