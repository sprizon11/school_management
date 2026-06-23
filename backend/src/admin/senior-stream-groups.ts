export const SENIOR_STREAM_GROUPS = [
  'Accounts',
  'Business Maths',
  'Commerce',
  'Computer Science',
  'B.Sc Computer Science',
  'Biology (Science)',
  'Pure Science',
  'Arts',
  'Vocational',
] as const;

export type SeniorStreamGroup = (typeof SENIOR_STREAM_GROUPS)[number];

export function isSeniorGrade(grade: number) {
  return grade === 11 || grade === 12;
}

export function normalizeStreamGroup(value?: string | null) {
  return (value ?? '').trim();
}

export function validateStreamGroupForGrade(grade: number, streamGroup?: string) {
  if (!isSeniorGrade(grade)) return '';
  const group = normalizeStreamGroup(streamGroup);
  if (!group) {
    throw new Error('GROUP_REQUIRED');
  }
  if (!SENIOR_STREAM_GROUPS.includes(group as SeniorStreamGroup)) {
    throw new Error('GROUP_INVALID');
  }
  return group;
}
