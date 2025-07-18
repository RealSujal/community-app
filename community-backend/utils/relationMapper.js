// utils/relationMapper.js
const relationMap = {
    father: {
        son: "son",
        daughter: "daughter",
        wife: "wife",
        husband: "self",
        father: "father",
        mother: "mother",
        brother: "brother",
        sister: "sister",
    },
    mother: {
        son: "son",
        daughter: "daughter",
        husband: "husband",
        wife: "self",
        father: "father",
        mother: "mother",
        brother: "brother",
        sister: "sister",
    },
    son: {
        father: "father",
        mother: "mother",
        sister: "sister",
        brother: "brother",
        wife: "wife",
        husband: "self",
        son: "son",
        daughter: "daughter",
    },
    daughter: {
        father: "father",
        mother: "mother",
        sister: "sister",
        brother: "brother",
        husband: "husband",
        wife: "self",
        son: "son",
        daughter: "daughter",
    },
    wife: {
        husband: "husband",
        son: "son",
        daughter: "daughter",
        father: "father-in-law",
        mother: "mother-in-law",
        brother: "brother-in-law",
        sister: "sister-in-law",
    },
    husband: {
        wife: "wife",
        son: "son",
        daughter: "daughter",
        father: "father-in-law",
        mother: "mother-in-law",
        brother: "brother-in-law",
        sister: "sister-in-law",
    },
    brother: {
        brother: "brother",
        sister: "sister",
        father: "father",
        mother: "mother",
    },
    sister: {
        brother: "brother",
        sister: "sister",
        father: "father",
        mother: "mother",
    },
    // more relations can be added here
};

/**
 * Maps one relation to another from a person's perspective.
 * @param {string} fromRelation - Relation of the current person to head.
 * @param {string} toRelation - Relation of the other member to head.
 * @returns {string} - Computed relation from current person’s perspective.
 */

function getRelation(fromRelation, toRelation) {
    if (!fromRelation || !toRelation) return "relative";
    const from = fromRelation.toLowerCase();
    const to = toRelation.toLowerCase();
    if (relationMap[from] && relationMap[from][to]) {
        return relationMap[from][to];
    }
    return "relative";
}

module.exports = { getRelation };