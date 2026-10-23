import { MESSAGE_TYPES, CONTENT_TYPES } from './constants';
import {
  isEvolutionInbox,
  hasReactionTarget,
} from './messageReactionEligibility';

export const canEditMessage = ({
  inbox,
  messageType,
  contentType,
  content,
  contentAttributes = {},
  privateMessage,
  sourceId,
  status,
}) => {
  return (
    isEvolutionInbox(inbox) &&
    hasReactionTarget(contentAttributes, sourceId) &&
    messageType === MESSAGE_TYPES.OUTGOING &&
    contentType === CONTENT_TYPES.TEXT &&
    Boolean(content) &&
    Boolean(sourceId) &&
    !privateMessage &&
    !contentAttributes.deleted &&
    !['failed', 'progress'].includes(status)
  );
};
