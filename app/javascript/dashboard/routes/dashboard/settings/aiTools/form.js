export const METHOD_OPTIONS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].map(
  value => ({ value, label: value })
);

export const newTool = () => ({
  name: '',
  description: '',
  active: false,
  allow_in_playground: false,
  slug: '',
  secret_headers: {},
  configuration: {
    method: 'GET',
    url: '',
    timeout_seconds: 10,
    parameters: [],
    headers: {},
    query_params: {},
    body: {},
  },
});

export const validHttpUrl = value => {
  try {
    return ['http:', 'https:'].includes(new URL(value).protocol);
  } catch {
    return false;
  }
};
