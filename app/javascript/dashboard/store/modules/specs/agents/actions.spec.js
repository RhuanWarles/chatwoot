import axios from 'axios';
import { actions } from '../../agents';
import * as types from '../../../mutation-types';
import agentList from './fixtures';

const commit = vi.fn();
const dispatch = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  describe('#get', () => {
    it('sends correct actions if API is success', async () => {
      axios.get.mockResolvedValue({ data: agentList });
      await actions.get({ commit });
      expect(commit.mock.calls).toEqual([
        [types.default.SET_AGENT_FETCHING_STATUS, true],
        [types.default.SET_AGENT_FETCHING_STATUS, false],
        [types.default.SET_AGENTS, agentList],
      ]);
    });
    it('sends correct actions if API is error', async () => {
      axios.get.mockRejectedValue({ message: 'Incorrect header' });
      await actions.get({ commit });
      expect(commit.mock.calls).toEqual([
        [types.default.SET_AGENT_FETCHING_STATUS, true],
        [types.default.SET_AGENT_FETCHING_STATUS, false],
      ]);
    });
  });

  describe('#create', () => {
    it('sends correct actions if API is success', async () => {
      axios.post.mockResolvedValue({ data: agentList[0] });
      await actions.create({ commit }, agentList[0]);
      expect(commit.mock.calls).toEqual([
        [types.default.SET_AGENT_CREATING_STATUS, true],
        [types.default.ADD_AGENT, agentList[0]],
        [types.default.SET_AGENT_CREATING_STATUS, false],
      ]);
    });
    it('sends correct actions if API is error', async () => {
      axios.post.mockRejectedValue({ message: 'Incorrect header' });
      await expect(actions.create({ commit })).rejects.toEqual({
        message: 'Incorrect header',
      });
      expect(commit.mock.calls).toEqual([
        [types.default.SET_AGENT_CREATING_STATUS, true],
        [types.default.SET_AGENT_CREATING_STATUS, false],
      ]);
    });
  });

  describe('#update', () => {
    it('sends correct actions if API is success', async () => {
      axios.patch.mockResolvedValue({ data: agentList[0] });
      await actions.update({ commit }, agentList[0]);
      expect(commit.mock.calls).toEqual([
        [types.default.SET_AGENT_UPDATING_STATUS, true],
        [types.default.EDIT_AGENT, agentList[0]],
        [types.default.SET_AGENT_UPDATING_STATUS, false],
      ]);
    });
    it('sends correct actions if API is error', async () => {
      axios.patch.mockRejectedValue({ message: 'Incorrect header' });
      await expect(actions.update({ commit }, agentList[0])).rejects.toThrow(
        Error
      );
      expect(commit.mock.calls).toEqual([
        [types.default.SET_AGENT_UPDATING_STATUS, true],
        [types.default.SET_AGENT_UPDATING_STATUS, false],
      ]);
    });
  });

  describe('#confirm', () => {
    beforeEach(() => commit.mockClear());

    it('confirms the agent in the server and updates it in the list', async () => {
      const confirmed = { ...agentList[0], confirmed: true };
      axios.post.mockResolvedValue({ data: confirmed });
      await actions.confirm({ commit }, agentList[0].id);
      expect(axios.post).toHaveBeenCalledWith(
        expect.stringMatching(new RegExp(`/agents/${agentList[0].id}/confirm$`))
      );
      expect(commit.mock.calls).toEqual([
        [types.default.EDIT_AGENT, confirmed],
      ]);
    });

    it('lets the error go up so the screen can warn the administrator', async () => {
      axios.post.mockRejectedValue(new Error('403'));
      await expect(actions.confirm({ commit }, 1)).rejects.toThrow('403');
      expect(commit).not.toHaveBeenCalled();
    });
  });

  describe('#delete', () => {
    it('sends correct actions if API is success', async () => {
      axios.delete.mockResolvedValue({ data: agentList[0] });
      await actions.delete({ commit }, agentList[0].id);
      expect(commit.mock.calls).toEqual([
        [types.default.SET_AGENT_DELETING_STATUS, true],
        [types.default.DELETE_AGENT, agentList[0].id],
        [types.default.SET_AGENT_DELETING_STATUS, false],
      ]);
    });
    it('sends correct actions if API is error', async () => {
      axios.delete.mockRejectedValue({ message: 'Incorrect header' });
      await expect(actions.delete({ commit }, agentList[0].id)).rejects.toThrow(
        Error
      );
      expect(commit.mock.calls).toEqual([
        [types.default.SET_AGENT_DELETING_STATUS, true],
        [types.default.SET_AGENT_DELETING_STATUS, false],
      ]);
    });
  });

  describe('#updatePresence', () => {
    it('sends correct actions', async () => {
      const data = { users: { 1: 'online' }, contacts: { 2: 'online' } };
      actions.updatePresence({ commit, dispatch }, data);
      expect(commit.mock.calls).toEqual([
        [types.default.UPDATE_AGENTS_PRESENCE, data],
      ]);
    });
  });

  describe('#updateSingleAgentPresence', () => {
    it('sends correct actions', async () => {
      const data = { id: 1, availabilityStatus: 'online' };
      actions.updateSingleAgentPresence({ commit, dispatch }, data);
      expect(commit.mock.calls).toEqual([
        [types.default.UPDATE_SINGLE_AGENT_PRESENCE, data],
      ]);
    });
  });
});
