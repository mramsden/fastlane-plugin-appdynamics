describe Fastlane::Actions::AppdynamicsAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The appdynamics plugin is working!")

      Fastlane::Actions::AppdynamicsAction.run(nil)
    end
  end
end
