import _ from "lodash";
import {
  RECEIVE_OBSERVATIONS,
  UPDATE_OBSERVATION_IN_COLLECTION,
  UPDATE_ALL_LOCAL,
  SET_REVIEWING
} from "../actions";

const observationsReducer = ( state = {
  results: [],
  reviewing: false
}, action ) => {
  if ( action.type === RECEIVE_OBSERVATIONS ) {
    return Object.assign( {}, state, {
      totalResults: action.totalResults,
      page: action.page,
      totalPages: action.totalPages,
      results: action.results
    } );
  }
  if ( action.type === UPDATE_OBSERVATION_IN_COLLECTION ) {
    const newState = Object.assign( {}, state, {
      results: _.cloneDeep( state.results ).map( obs => {
        if ( obs.id !== action.observation.id ) {
          return obs;
        }
        const newObs = _.cloneDeep( obs );
        _.forOwn( action.changes, ( v, k ) => {
          newObs[k] = v;
        } );
        return newObs;
      } )
    } );
    return newState;
  }
  if ( action.type === UPDATE_ALL_LOCAL ) {
    const newState = Object.assign( {}, state, {
      results: _.cloneDeep( state.results ).map( obs => {
        const newObs = _.cloneDeep( obs );
        _.forOwn( action.changes, ( v, k ) => {
          newObs[k] = v;
        } );
        return newObs;
      } )
    } );
    return newState;
  }
  if ( action.type === SET_REVIEWING ) {
    const newState = Object.assign( {}, state, {
      reviewing: action.reviewing
    } );
    return newState;
  }
  return state;
};

export default observationsReducer;
