import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import inatjs from "inaturalistjs";
import _ from "lodash";
import UserImage from "../../../shared/components/user_image";
import GenerateStatsButton from "./generate_stats_button";
import Summary from "./summary";
import Observations from "./observations";
import Identifications from "./identifications";
import Taxa from "./taxa";
import Publications from "./publications";

const App = ( {
  year,
  user,
  currentUser,
  site,
  data,
  rootTaxonID
} ) => {
  let body = "todo";
  const inatUser = user ? new inatjs.User( user ) : null;
  if ( !year ) {
    body = (
      <p className="alert alert-warning">
        Not a valid year. Please choose a year between 1950 and { new Date().getYear() }.
      </p>
    );
  } else if ( !data || !currentUser ) {
    if ( user && currentUser && user.id === currentUser.id ) {
      body = (
        <GenerateStatsButton user={user} year={year} />
      );
    } else {
      body = (
        <p className="alert alert-warning">
          { I18n.t( "stats_for_this_year_have_not_been_generated" ) }
        </p>
      );
    }
  } else {
    body = (
      <div>
        <center>
          <a href="#sharing" className="btn btn-default btn-share btn-bordered">
            { I18n.t( "share" ) }
            { " " }
            <i className="fa fa-share-square-o" />
          </a>
        </center>
        <Summary data={data} user={user} year={year} />
        <Observations data={data.observations} user={user} year={year} site={site} />
        <Identifications data={data.identifications} user={user} />
        <Taxa
          data={data.taxa}
          rootTaxonID={rootTaxonID}
          year={year}
          user={user}
          currentUser={currentUser}
        />
        { user && currentUser && user.id === currentUser.id ? (
          <GenerateStatsButton user={user} year={year} text={I18n.t( "regenerate_stats" )} />
        ) : null }
        { data.publications && (
          <Publications data={data.publications} year={year} />
        ) }
        <h2 id="sharing"><a name="sharing" href="#sharing"><span>{ I18n.t( "share" ) }</span></a></h2>
        <center>
          <div
            className="fb-share-button"
            data-href={window.location.toString( ).replace( /#.+/, "" )}
            data-layout="button"
            data-size="large"
            data-mobile-iframe="true"
          >
            <a
              className="fb-xfbml-parse-ignore"
              target="_blank"
              rel="noopener noreferrer"
              href={`https://www.facebook.com/sharer/sharer.php?u=${window.location.toString( ).replace( /#.+/, "" )}&amp;src=sdkpreparse`}
            >
              { I18n.t( "facebook" ) }
            </a>
          </div>
          <a
            className="twitter-share-button"
            href={`https://twitter.com/intent/tweet?text=Check+these+${year}+${site.site_name_short || site.name}+stats!&url=${window.location.toString( ).replace( /#.+/, "" )}`}
            data-size="large"
          >
            { I18n.t( "twitter" ) }
          </a>
        </center>
      </div>
    );
  }
  let montageObservations = [];
  if (
    data
    && data.observations
    && data.observations.popular
    && data.observations.popular.length > 0
  ) {
    montageObservations = _.filter(
      data.observations.popular, o => ( o.photos && o.photos.length > 0 )
    );
    while ( montageObservations.length < 150 ) {
      montageObservations = montageObservations.concat( montageObservations );
    }
  }
  return (
    <div id="YearStats">
      <div className="banner">
        <div className="montage">
          <div className="photos">
            { _.map( montageObservations, ( o, i ) => (
              <a href={`/observations/${o.id}`} key={`montage-obs-${i}`}>
                <img
                  alt={o.species_guess}
                  src={o.photos[0].url.replace( "square", "thumb" )}
                  width={
                    ( 50 / o.photos[0].original_dimensions.height )
                    * o.photos[0].original_dimensions.width
                  }
                  height={
                    ( 50 / o.photos[0].original_dimensions.height )
                    * o.photos[0].original_dimensions.height
                  }
                />
              </a>
            ) ) }
          </div>
        </div>
        { inatUser ? (
          <div>
            <UserImage user={inatUser} />
            <div className="ribbon-container">
              <div className="ribbon">
                <div className="ribbon-content">
                  { inatUser.name ? `${inatUser.name} (${inatUser.login})` : inatUser.login }
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="protector">
            <div className="site-icon">
              <img src={site.icon_url} alt={site.name} />
            </div>
            <div className="ribbon-container">
              <div className="ribbon">
                <div className="ribbon-content">
                  { site.name }
                </div>
              </div>
            </div>
          </div>
        ) }

      </div>
      <Grid>
        <Row>
          <Col xs={12}>
            <h1>
              {
                I18n.t( "year_in_review", {
                  year
                } )
              }
            </h1>
          </Col>
        </Row>
        <Row>
          <Col xs={12}>
            { body }
            <div id="view-stats-buttons">
              { !currentUser || !user || ( user.id !== currentUser.id ) ? (
                <div>
                  <a href={`/stats/${year}/you`} className="btn btn-default btn-bordered">
                    <i className="fa fa-pie-chart" />
                    { " " }
                    { I18n.t( "view_your_year_stats", { year } ) }
                  </a>
                </div>
              ) : null }
              { user ? (
                <div>
                  <a href={`/stats/${year}`} className="btn btn-default btn-bordered">
                    <i className="fa fa-bar-chart-o" />
                    { " " }
                    { I18n.t( "view_year_stats_for_site", { year, site: site.name } ) }
                  </a>
                </div>
              ) : null }
            </div>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

App.propTypes = {
  year: PropTypes.number,
  user: PropTypes.object,
  currentUser: PropTypes.object,
  data: PropTypes.object,
  site: PropTypes.object,
  rootTaxonID: PropTypes.number
};

export default App;
