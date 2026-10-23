const DEFAULT_ICON = '/android-icon-192x192.png';

export const getDesktopPermission = () =>
  typeof Notification === 'undefined' ? 'unsupported' : Notification.permission;

// Must run inside a user gesture (a click on the settings toggle)
export const requestDesktopPermission = async () =>
  getDesktopPermission() === 'default'
    ? Notification.requestPermission()
    : getDesktopPermission();

export const showDesktopNotification = ({
  title,
  body,
  icon,
  tag,
  silent,
  requireInteraction,
  onClick,
}) => {
  try {
    const notification = new Notification(title, {
      body,
      icon: icon || DEFAULT_ICON,
      tag,
      silent,
      requireInteraction,
    });
    notification.onclick = () => {
      window.focus();
      notification.close();
      onClick();
    };
  } catch (error) {
    // Android browsers only allow notifications created by a service worker; the popup and sound still work
  }
};
