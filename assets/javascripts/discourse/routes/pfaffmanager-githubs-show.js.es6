import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  controllerName: "githubs-show",

  model(params) {
    return this.store.find("github", params.id);
  },

  renderTemplate() {
    this.render("githubs-show");
  },
});
