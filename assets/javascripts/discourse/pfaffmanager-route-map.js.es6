export default function() {
  this.route("pfaffmanager", function() {
    this.route("actions", function() {
      this.route("show", { path: "/:id" });
    });
  });
};
