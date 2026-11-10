import { Button } from 'tgui-core/components';

let url: string | null = null;

const rememberServerUrl = (attempts = 3) => {
  Byond.winget('', 'url').then((currentUrl) => {
    // A disconnected client can report an address with no usable port.
    if (currentUrl && !currentUrl.endsWith(':0')) {
      url = currentUrl;
    } else if (attempts > 1) {
      setTimeout(() => rememberServerUrl(attempts - 1), 1000);
    }
  });
};

if (Byond.IS_BYOND) {
  rememberServerUrl();
}

export const ReconnectButton = () => {
  return (
    <>
      <Button
        color="white"
        onClick={() => {
          Byond.command('.reconnect');
        }}
      >
        Reconnect
      </Button>
      {url && (
        <Button
          color="white"
          icon="power-off"
          tooltip="Relaunch game"
          tooltipPosition="bottom-end"
          onClick={() => {
            location.href = `byond://${url}`;
            Byond.command('.quit');
          }}
        />
      )}
    </>
  );
};
