module Bosh::Workspace
  module ProjectDeploymentHelper

    def project_deployment?
      File.exists?(project_deployment_file) &&
        project_deployment_file?(project_deployment_file)
    end

    def project_deployment
      @project_deployment ||= ProjectDeployment.new(project_deployment_file)
    end

    def project_deployment=(deployment)
      @project_deployment = ProjectDeployment.new(deployment)
    end

    def project_deployment_file?(deployment)
      ProjectDeployment.new(deployment).manifest.has_key?("templates")
    end

    def require_project_deployment
      no_deployment_err unless deployment
      not_a_bosh_workspace_deployment unless project_deployment?
      validate_project_deployment
    end

    def no_deployment_err
      err "No deployment set"
    end

    def not_a_bosh_workspace_deployment
      err "Deployment is not a bosh-workspace deployment: #{deployment}"
    end

    def create_placeholder_deployment
      resolve_director_uuid

      File.open(project_deployment.merged_file, "w") do |file|
        file.write(placeholder_deployment_content)
      end
    end

    def validate_project_deployment
      unless project_deployment.valid?
        say("Validation errors:".make_red)
        project_deployment.errors.each { |error| say("- #{error}") }
        err("'#{project_deployment.file}' is not valid".make_red)
      end
    end

    def build_project_deployment
      resolve_director_uuid

      say("Generating deployment manifest")
      ManifestBuilder.build(project_deployment, work_dir)

      if domain_name = project_deployment.domain_name
        say("Transforming to dynamic networking (dns)")
        DnsHelper.transform(project_deployment.merged_file, domain_name)
      end
    end

    def resolve_director_uuid
      use_targeted_director_uuid if director_uuid_current?
    end

    def offline!
      @offline = true
    end

    def offline?
      @offline
    end

    private

    def use_targeted_director_uuid
      project_deployment.director_uuid = bosh_uuid
    end

    def no_warden_error
      say("Please put 'director_uuid: #{bosh_uuid}' in '#{deployment}'")
      err("'director_uuid: current' may not be used in production")
    end

    def director_uuid_current?
      project_deployment.director_uuid == "current"
    end

    def warden_cpi?
      bosh_status["cpi"] == "warden" || bosh_status["name"] =~ /Bosh Lite/i
    end

    def project_deployment_file
      @project_deployment_file ||= begin
        path = File.join(deployment_dir, "../deployments", deployment_basename)
        File.expand_path path
      end
    end

    def deployment_dir
      File.dirname(deployment)
    end

    def deployment_basename
      File.basename(deployment)
    end

    def placeholder_deployment_content
      { "director_uuid" => project_deployment.director_uuid }.to_yaml +
        "# Don't edit; placeholder deployment for: #{project_deployment.file}"
    end

    def bosh_status
      @bosh_status ||= director.get_status
    end

    def bosh_uuid
      bosh_status["uuid"]
    end
  end
end
