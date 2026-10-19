import { Box, Button, NumberInput, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../../backend';
import { type BuildModeData, Sprite } from './common';

const directions: [number, string, string][] = [
  [9, '↖', 'Северо-запад'],
  [1, '↑', 'Север'],
  [5, '↗', 'Северо-восток'],
  [8, '←', 'Запад'],
  [0, '·', 'Направление'],
  [4, '→', 'Восток'],
  [10, '↙', 'Юго-запад'],
  [2, '↓', 'Юг'],
  [6, '↘', 'Юго-восток'],
];
const copyPath = (path: string) => {
  const input = document.createElement('textarea');
  input.value = path;
  input.style.position = 'fixed';
  input.style.opacity = '0';
  document.body.appendChild(input);
  input.focus();
  input.select();
  document.execCommand('copy');
  input.remove();
};

export const SpawnInspector = () => {
  const { act, data } = useBackend<BuildModeData>();
  const selected = data.selected;
  return (
    <aside className="BuildMode__inspector">
      {selected ? (
        <>
          <Sprite item={selected} large />
          <Box fontSize="18px" bold my={1}>
            {selected.name}
          </Box>
          {selected.desc && (
            <Box className="BuildMode__description" mb={1}>
              {selected.desc}
            </Box>
          )}
          <Box className="BuildMode__path">{selected.path}</Box>
          <Stack mb={1}>
            <Stack.Item grow>
              <Button
                fluid
                icon="star"
                selected={!!selected.favorite}
                onClick={() => act('favorite', { path: selected.path })}
              >
                Избранное
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="copy"
                tooltip="Копировать путь"
                onClick={() => copyPath(selected.path)}
              />
            </Stack.Item>
          </Stack>
          <Section title="Размещение">
            <Stack align="center" justify="space-between" mb={1}>
              <Stack.Item>Количество</Stack.Item>
              <Stack.Item>
                <NumberInput
                  width="65px"
                  value={selected.is_turf ? 1 : data.amount}
                  disabled={!!selected.is_turf}
                  minValue={1}
                  maxValue={data.max_amount}
                  step={1}
                  onChange={(value) => act('amount', { value })}
                />
              </Stack.Item>
            </Stack>
            <div className="BuildMode__directions">
              {directions.map(([value, arrow, label]) =>
                value ? (
                  <Button
                    key={value}
                    tooltip={label}
                    selected={data.direction === value}
                    onClick={() => act('direction', { value })}
                  >
                    {arrow}
                  </Button>
                ) : (
                  <span key={value}>{arrow}</span>
                ),
              )}
            </div>
            {!selected.is_turf && (
              <Stack align="center" mt={1}>
                <Stack.Item>Сдвиг</Stack.Item>
                {(['x', 'y'] as const).map((axis) => (
                  <Stack.Item key={axis} grow>
                    <NumberInput
                      fluid
                      value={data[`pixel_${axis}`]}
                      minValue={-data.max_offset}
                      maxValue={data.max_offset}
                      step={1}
                      unit={axis.toUpperCase()}
                      onChange={(value) => act(`pixel_${axis}`, { value })}
                    />
                  </Stack.Item>
                ))}
              </Stack>
            )}
            <Button
              mt={1}
              fluid
              color="transparent"
              icon="undo"
              onClick={() => act('reset')}
            >
              Сбросить
            </Button>
          </Section>
          <Button
            fluid
            icon="mouse-pointer"
            selected={!!data.armed}
            onClick={() => act('arm')}
          >
            На карту
          </Button>
          <Button
            fluid
            mt={0.5}
            icon="map-marker-alt"
            onClick={() => act('spawn_here')}
          >
            К ногам
          </Button>
          {!!selected.is_item && (
            <Button
              fluid
              mt={0.5}
              icon="hand-paper"
              disabled={!data.can_hands}
              tooltip="Если руки заняты — на землю"
              onClick={() => act('spawn_hands')}
            >
              В руки
            </Button>
          )}
          <Button
            fluid
            mt={0.5}
            color="transparent"
            onClick={() => act('cancel')}
          >
            Снять выбор
          </Button>
        </>
      ) : (
        <div className="BuildMode__empty">
          <Box fontSize="18px" mb={1}>
            Выберите объект
          </Box>
        </div>
      )}
    </aside>
  );
};
