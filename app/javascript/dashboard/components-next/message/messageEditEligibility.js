import { MESSAGE_TYPES, CONTENT_TYPES } from './constants';
import {
  isEvolutionInbox,
  hasReactionTarget,
} from './messageReactionEligibility';

const EDIT_WINDOW_MS = 15 * 60 * 1000;

export const canEditMessage = ({
  inbox,
  messageType,
  contentType,
  content,
  contentAttributes = {},
  privateMessage,
  sourceId,
  status,
  createdAt,
}) => {
  const isWithinEditWindow =
    Number.isFinite(createdAt) &&
    Date.now() - createdAt * 1000 <= EDIT_WINDOW_MS;

  return (
    isEvolutionInbox(inbox) &&
    hasReactionTarget(contentAttributes, sourceId) &&
    messageType === MESSAGE_TYPES.OUTGOING &&
    contentType === CONTENT_TYPES.TEXT &&
    Boolean(content) &&
    !privateMessage &&
    !contentAttributes.deleted &&
    !['failed', 'progress'].includes(status) &&
    isWithinEditWindow
  );
};
