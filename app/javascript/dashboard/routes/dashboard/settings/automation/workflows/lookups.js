import { buildCustomFields } from './fields';

const sortByName = items =>
  [...items].sort((a, b) => String(a.label).localeCompare(String(b.label)));

/**
 * Pure lookup builder. `source` carries plain arrays:
 * agents, teams, inboxes, labels (store records), pipelines (with stages), segments,
 * lostReasons, dealFields (crm custom fields) and contactAttributes (attribute definitions).
 * Option values for ids are numbers; ValueInput converts them to strings for conditions.
 */
export const buildLookups = (source, t = key => key) => {
  const pick = (items, label = 'name') =>
    (items || []).map(item => ({ value: item.id, label: item[label] }));

  const pipelines = source.pipelines || [];
  const stagesOf = pipelineId => {
    const pipeline = pipelines.find(
      item => String(item.id) === String(pipelineId)
    );
    return [...(pipeline?.stages || [])]
      .sort((a, b) => a.position - b.position)
      .map(stage => ({ value: stage.id, label: stage.name }));
  };
  const allStages = pipelines.flatMap(pipeline =>
    (pipeline.stages || []).map(stage => ({
      value: stage.id,
      label: `${pipeline.name} › ${stage.name}`,
    }))
  );

  const lists = {
    agent: pick(source.agents),
    team: pick(source.teams),
    inbox: pick(source.inboxes),
    pipeline: sortByName(pick(pipelines)),
    stage: allStages,
    segment: pick(
      (source.segments || []).filter(item => item.active !== false)
    ),
    lost_reason: pick(
      (source.lostReasons || []).filter(item => item.active !== false)
    ),
  };

  // Inactive records still resolve to their name so old nodes stay readable. Stages resolve to
  // their own name: summaries print the pipeline next to them.
  const namePool = {
    ...lists,
    stage: pipelines.flatMap(pipeline =>
      (pipeline.stages || []).map(stage => ({
        value: stage.id,
        label: stage.name,
      }))
    ),
    segment: pick(source.segments),
    lost_reason: pick(source.lostReasons),
  };

  const name = (kind, id) => {
    if (id === '' || id === null || id === undefined) return '';
    const found = (namePool[kind] || []).find(
      item => String(item.value) === String(id)
    );
    return found ? found.label : `#${id}`;
  };

  const labelOptions = (source.labels || []).map(item => ({
    value: item.title,
    label: item.title,
  }));

  return {
    t,
    name,
    stagesOf,
    labelOptions,
    customFields: buildCustomFields(
      source.dealFields,
      source.contactAttributes
    ),
    dealFields: (source.dealFields || [])
      .filter(item => item.active !== false)
      .map(item => ({ value: item.key, label: item.name, field: item })),
    contactFields: (source.contactAttributes || []).map(item => ({
      value: item.attribute_key,
      label: item.attribute_display_name,
      field: item,
    })),
    options: kind => lists[kind] || [],
  };
};
