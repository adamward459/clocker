import SwiftUI

struct ProjectsPage: View {
    @EnvironmentObject var clockModel: ClockModel
    var navigateBack: () -> Void
    var isVisible: Bool = false

    @State private var backHovered = false
    @State private var isEditing = false
    @State private var editingProjectID: String?
    @State private var editingName = ""
    @State private var newProjectName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button(action: navigateBack) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(ClockerTheme.Fonts.navBackIcon)
                        Text("Back")
                            .font(ClockerTheme.Fonts.navBack)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
                            .fill(backHovered ? ClockerTheme.Colors.hoverFill : .clear)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .onHover { backHovered = $0 }
                .animation(.easeInOut(duration: 0.15), value: backHovered)

                Spacer()

                Text("Projects")
                    .font(ClockerTheme.Fonts.navTitle)

                Spacer()

                Button(isEditing ? "Done" : "Edit") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isEditing.toggle()
                        editingProjectID = nil
                    }
                }
                .font(ClockerTheme.Fonts.navBack)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)

            // Project list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(clockModel.orderedProjects) { project in
                        projectRow(project)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)

            Divider()
                .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)

            // New project
            HStack(spacing: 6) {
                TextField("New project", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                    .font(ClockerTheme.Fonts.caption)
                    .onSubmit(createProject)

                Button {
                    createProject()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)
            .padding(.vertical, ClockerTheme.Spacing.sectionGap)
        }
    }

    @ViewBuilder
    private func projectRow(_ project: ClockProject) -> some View {
        let isActive = project.id == clockModel.activeProjectID

        if editingProjectID == project.id {
            // Inline rename
            HStack(spacing: 6) {
                TextField("Name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .font(ClockerTheme.Fonts.caption)
                    .onSubmit { commitRename() }

                Button {
                    commitRename()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)

                Button {
                    editingProjectID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, ClockerTheme.Spacing.rowHorizontal)
            .padding(.vertical, 5)
            .padding(.horizontal, ClockerTheme.Spacing.rowOuterPadding)
        } else if isEditing {
            // Edit mode row
            HStack(spacing: 8) {
                if !project.isDefault {
                    Button {
                        clockModel.deleteProject(project.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }

                Text(project.name)
                    .font(ClockerTheme.Fonts.rowLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Button {
                    editingProjectID = project.id
                    editingName = project.name
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, ClockerTheme.Spacing.rowHorizontal)
            .padding(.vertical, ClockerTheme.Spacing.rowVertical)
            .padding(.horizontal, ClockerTheme.Spacing.rowOuterPadding)
        } else {
            // Normal selection row
            Button {
                clockModel.switchToProject(project.id)
                navigateBack()
            } label: {
                HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                    Text(project.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(MenuRowButtonStyle())
        }
    }

    private func commitRename() {
        if let id = editingProjectID {
            clockModel.renameProject(id, to: editingName)
        }
        editingProjectID = nil
        editingName = ""
    }

    private func createProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if clockModel.createProject(named: name) != nil {
            newProjectName = ""
        }
    }
}
