import { Box, Button } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { CatalogBrowser, CatalogSidebar } from './BuildMode/Catalog';
import { type BuildModeData } from './BuildMode/common';
import { SpawnInspector } from './BuildMode/Inspector';

export const BuildMode = () => {
  const { act, data } = useBackend<BuildModeData>();
  return (
    <Window
      width={1100}
      height={760}
      title="F7 · Каталог спавна"
      theme="azure_default"
      rememberSize
    >
      <Window.Content fitted className="BuildMode">
        <div className="BuildMode__header">
          <div>
            <Box className="BuildMode__heading">Каталог спавна</Box>
          </div>
          <div className="BuildMode__state">
            <Box className="BuildMode__mode">
              {data.armed
                ? 'Размещение'
                : data.mode === 'catalog'
                  ? 'Удаление'
                  : `Инструмент: ${data.mode}`}
            </Box>
            <Button
              icon="sign-out-alt"
              color="transparent"
              onClick={() => act('quit')}
            >
              Выйти
            </Button>
          </div>
        </div>
        <div className="BuildMode__body">
          <CatalogSidebar />
          <CatalogBrowser />
          <SpawnInspector />
        </div>
        <div className="BuildMode__footer">
          <span className="BuildMode__status">
            {data.status ||
              (data.mode === 'catalog'
                ? data.armed
                  ? 'ЛКМ — спавн · ПКМ — отмена · Alt + ЛКМ — выбрать тип'
                  : 'ПКМ — удалить · Alt + ЛКМ — выбрать тип'
                : `Инструмент: ${data.mode}`)}
          </span>
        </div>
      </Window.Content>
    </Window>
  );
};
