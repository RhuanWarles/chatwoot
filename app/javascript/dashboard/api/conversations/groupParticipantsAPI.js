import ApiClient from 'dashboard/api/ApiClient';

class GroupParticipantsAPI extends ApiClient {
  constructor(conversationId) {
    super(`conversations/${conversationId}/group_participants`, {
      accountScoped: true,
    });
  }

  get() {
    return super.get();
  }
}

export default conversationId => new GroupParticipantsAPI(conversationId);
