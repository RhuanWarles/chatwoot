/* global axios */
import ApiClient from '../ApiClient';

class MessageReactionsAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  react(conversationId, messageId, emoji) {
    return axios.post(
      `${this.url}/${conversationId}/messages/${messageId}/reaction`,
      { emoji }
    );
  }
}

export default new MessageReactionsAPI();
